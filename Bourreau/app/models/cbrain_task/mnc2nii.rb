
#
# CBRAIN Project
#
# CbrainTask subclass
#
# Original author: Mathieu Desrosiers
#
# $Id$
#

#A subclass of ClusterTask to run mnc2nii.
class CbrainTask::Mnc2nii < ClusterTask

  Revision_info="$Id$"

  include RestartableTask # This task is naturally restartable
  include RecoverableTask # This task is naturally recoverable

  def setup #:nodoc:
    params      = self.params
    mincfile_id = params[:mincfile_id]
    mincfile    = Userfile.find(mincfile_id)

    unless mincfile
      self.addlog("Could not find active record entry for file #{mincfile_id}")
      return false
    end

    mincfile.sync_to_cache
    cachename = mincfile.cache_full_path
    basename  = cachename.basename.to_s
    safe_symlink(cachename,basename)

    params[:data_provider_id] = mincfile.data_provider_id if params[:data_provider_id].blank?

    true
  end

  def cluster_commands #:nodoc:
    params      = self.params
    voxel_type  = params[:voxel_type]
    int_sign    = params[:voxel_int_signity]
    file_format = params[:file_format]

    mincfile_id = params[:mincfile_id]
    mincfile    = Userfile.find(mincfile_id)
    cachename   = mincfile.cache_full_path
    basename    = cachename.basename.to_s

    cb_error "Unexpected voxel type"     if voxel_type !~ /^(short|word|int|float|double|default)$/
    cb_error "Unexpected voxel int sign" if int_sign   !~ /^(signed|unsigned|default)$/

    if voxel_type == "default"
      voxel_type = ""
    else
      voxel_type = "-#{voxel_type}"
    end

    voxel_sign = ""
    if voxel_type =~ /^(short|word|int)$/ && int_sign =~ /^(signed|unsigned)$/
      voxel_sign = "-#{int_sign}"
    end

    file_format = params[:file_format]
    file_format = "-#{file_format}"

    command = "mnc2nii #{voxel_type} #{voxel_sign} #{file_format} #{basename}"

    out_files = Dir.glob("*.{img,hdr,nii,nia}")
    out_files.each do |f|
      File.unlink(f) rescue true
    end

    [
      "source #{CBRAIN::Quarantine_dir}/init.sh",
      "echo \"Command: #{command}\"",
      command
    ]
  end

  def save_results #:nodoc:
    params      = self.params
    mincfile_id = params[:mincfile_id]
    mincfile    = Userfile.find(mincfile_id)
    cachename   = mincfile.cache_full_path
    basename    = cachename.basename.to_s
    shortbase   = basename.sub(/\.mi?nc(\.g?z)?$/i,"")
    group_id    = mincfile.group_id

    user_id          = self.user_id
    data_provider_id = params[:data_provider_id]

    out_files = Dir.glob("*.{img,hdr,nii,nia}")
    if out_files.size == 0
      self.addlog("Could not find any output files?!?")
      return false
    end

    niifiles = []
    out_files.each do |file|
      self.addlog("Found raw output file '#{file}'.")
      niifile = safe_userfile_find_or_new(SingleFile,
        :name             => shortbase + File.extname(file),
        :user_id          => user_id,
        :group_id         => group_id,
        :data_provider_id => data_provider_id,
        :task             => "Mnc2nii"
      )
      niifile.cache_copy_from_local_file(file)
      if niifile.save
        niifile.move_to_child_of(mincfile)
        self.addlog("Saved output file #{niifile.name}") # not necessarily NIfTI format
        niifiles << niifile
      else
        self.addlog("Could not save back result file #{niifile.name}")
      end
    end

    params[:niifile_ids] = niifiles.map &:id
    self.addlog_to_userfiles_these_created_these( [ mincfile ], niifiles )

    true
  end

end
