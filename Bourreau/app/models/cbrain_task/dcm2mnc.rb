
#
# CBRAIN Project
#
# CbrainTask subclass
#
# Original author: Pierre Rioux
#
# $Id$
#

#A subclass of ClusterTask to run dcm2mnc.
class CbrainTask::Dcm2mnc < ClusterTask

  Revision_info="$Id$"

  include RestartableTask # This task is naturally restartable
  include RecoverableTask # This task is naturally recoverable

  def setup #:nodoc:
    params      = self.params
    dicom_colid = params[:dicom_colid]  # the ID of a FileCollection
    dicom_col   = Userfile.find(dicom_colid)

    unless dicom_col
      self.addlog("Could not find active record entry for file collection #{dicom_colid}")
      return false
    end

    unless dicom_col.is_a?(FileCollection)
      self.addlog("Error: ActiveRecord entry #{dicom_colid} is not a file collection.")
      return false
    end

    params[:data_provider_id] = dicom_col.data_provider_id if params[:data_provider_id].blank?

    dicom_col.sync_to_cache
    cachename = dicom_col.cache_full_path.to_s
    safe_symlink(cachename,"dicom_col")
    safe_mkdir("results",0700)

    true
  end

  def job_walltime_estimate #:nodoc:
    1.hours
  end

  def cluster_commands #:nodoc:
    params       = self.params
    use_coord = params[:use_coordinates] == "1" ? "-usecoordinates" : ""
    [
      "dcm2mnc #{use_coord} dicom_col results",
    ]
  end

  def save_results #:nodoc:
    params      = self.params
    dicom_colid = params[:dicom_colid]  # the ID of a FileCollection
    dicom_col   = Userfile.find(dicom_colid)

    relpaths = []
    IO.popen("find results -type f -name \"*.mnc*\" -print","r") do |io|
      io.each_line do |relpath|
        next unless relpath.match(/\.mnc(.gz)?\s*$/i)
        relpath.sub!(/\s+$/,"")
        relpaths << relpath
      end
    end

    numfail = 0
    numok   = 0

    mincfiles      = []
    orig_basenames = []

    FileUtils.remove_dir("renamed", true) rescue true
    safe_mkdir("renamed",0700)

    relpaths.each do |relpath|
      newrelpath   = rename_by_pattern(dicom_col.name,relpath)
      basename     = File.basename(newrelpath)
      mincfile = safe_userfile_find_or_new(MincFile,
        :name             => basename,
        :data_provider_id => params[:data_provider_id],
        :task             => "Dcm2mnc"
      )
      mincfile.cache_copy_from_local_file(newrelpath)
      if mincfile.save
        mincfile.move_to_child_of(dicom_col)
        numok += 1
        self.addlog("Saved new MINC file #{basename}")
        mincfiles      << mincfile
        orig_basenames << File.basename(relpath)
      else
        numfail += 1
        self.addlog("Could not save back result file '#{basename}'.")
      end
    end

    old_mincfile_ids = params[:created_mincfile_ids] || []
    new_mincfile_ids = mincfiles.map &:id

    if params[:erase_old_results] == "1" && numok > 0 && numfail == 0
      old_mincfile_ids -= new_mincfile_ids
      old_mincfile_ids.each do |id|
        u = Userfile.find(id) rescue nil
        next unless u
        u.destroy rescue true
        self.addlog("Erasing old result mincfile '#{u.name}'")
      end
    end

    params[:created_mincfile_ids]    = new_mincfile_ids
    params[:orig_mincfile_basenames] = orig_basenames

    self.addlog_to_userfiles_these_created_these([dicom_col],mincfiles)

    return true if numok > 0 && numfail == 0
    false
  end

  private

  def rename_by_pattern(dicom_name,orig_minc_relpath)
    pattern = self.params[:output_filename_pattern] || ""
    pattern.strip!
    if pattern.blank?
      return orig_minc_relpath # nothing to do really
    end

    # Create standard keywords
    now = Time.zone.now
    components = {
      "date"       => now.strftime("%Y-%m-%d"),
      "time"       => now.strftime("%H:%M:%S"),
      "task_id"    => self.id.to_s,
      "run_number" => self.run_number.to_s
    }

    # Add {dicom-N} keywords
    dcm_comps = dicom_name.split(/([a-z0-9]+)/i)
    1.step(dcm_comps.size-1,2) do |i|
      keyword = "dicom-#{(i-1)/2+1}"
      components[keyword] = dcm_comps[i]
    end

    # Add {minc-N} keywords
    minc_name = File.basename(orig_minc_relpath)
    mnc_comps = minc_name.split(/([a-z0-9]+)/i)
    1.step(mnc_comps.size-1,2) do |i|
      keyword = "minc-#{(i-1)/2+1}"
      components[keyword] = mnc_comps[i]
    end

    # Create new basename
    pat_comps = pattern.split(/(\{(?:[a-z_]+(?:-\d+)?)\})/i)
    final = ""
    pat_comps.each_with_index do |comp,i|
      if i.even?
        final += comp
      else
        comp.gsub!(/[{}]/,"")
        val = components[comp.downcase]
        cb_error "While building new filename, cannot find value for keyword '{#{comp.downcase}}'." if val.blank?
        final += val
      end
    end

    # Append .mnc or .mnc.gz if necessary
    final.sub!(/\.mi?nc(\.gz)?$/i,"")
    if orig_minc_relpath =~ /\.mi?nc\.gz$/i
      final += ".mnc.gz"
    else
      final += ".mnc"
    end

    # Validate it
    cb_error "Pattern for new filename produces an invalid filename: '#{final}'." unless
      Userfile.is_legal_filename?(final)

    # Create hard link with new name
    new_relpath = "renamed/#{final}"
    if File.exist?(new_relpath)
      cb_error "Error: it seems this task's renaming pattern mapped several of dcm2mnc's output mincfiles to the same new name '#{final}'."
    end

    File.link(orig_minc_relpath,new_relpath)

    return new_relpath

  end

end

