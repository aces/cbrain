
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

  def cluster_commands #:nodoc:
    params       = self.params
    [
      "source #{CBRAIN::Quarantine_dir}/init.sh",
      "dcm2mnc dicom_col results",
    ]
  end

  def save_results #:nodoc:
    params      = self.params
    dicom_colid = params[:dicom_colid]  # the ID of a FileCollection
    dicom_col   = Userfile.find(dicom_colid)
    user_id     = self.user_id

    io = IO.popen("find results -type f -name \"*.mnc\" -print","r")

    numfail = 0
    numok   = 0

    mincfiles = []
    io.each_line do |file|
      next unless file.match(/\.mnc\s*$/)
      file = file.sub(/\n$/,"")
      basename = File.basename(file)
      mincfile = safe_userfile_find_or_new(SingleFile,
        :name             => basename,
        :user_id          => user_id,
        :group_id         => dicom_col.group_id,
        :data_provider_id => params[:data_provider_id],
        :task             => "Dcm2mnc"
      )
      mincfile.cache_copy_from_local_file(file)
      if mincfile.save
        mincfile.move_to_child_of(dicom_col)
        numok += 1
        self.addlog("Saved new MINC file #{basename}")
        mincfiles << mincfile
      else
        numfail += 1
        self.addlog("Could not save back result file '#{basename}'.")
      end
    end

    io.close

    params[:created_mincfile_ids] = mincfiles.map &:id
    self.addlog_to_userfiles_these_created_these([dicom_col],mincfiles)

    return true if numok > 0 && numfail == 0
    false
  end

end

