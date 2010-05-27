
#
# CBRAIN Project
#
# CbrainTask subclass
#
# Original author: Mathieu Desrosiers
#
# $Id$
#

#A subclass of CbrainTask::ClusterTask to run mnc2nii.
class CbrainTask::Mnc2nii < CbrainTask::ClusterTask

  Revision_info="$Id$"

  def setup #:nodoc:
    params      = self.params
    minc_colid = params[:mincfile_id]  # the ID of a FileCollection
    minc_col   = Userfile.find(minc_colid)

    unless minc_col
      self.addlog("Could not find active record entry for file #{minc_colid}")
      return false
    end

    minc_col.sync_to_cache
    cachename = minc_col.cache_full_path
    File.symlink(cachename,"minc_col.mnc")
    minc_col.sync_to_cache
    params[:data_provider_id] ||= mincfile.data_provider.id

#    unless minc_col.class.to_s == "FileCollection"
#      self.addlog("Error: ActiveRecord entry #{minc_colid} is not a file collection.")
#      return false
#    end




    vaultname = minc_col.vaultname
    File.symlink(vaultname,"minc_col.mnc")
    pre_synchronize_userfile(minc_col)

    params[:data_provider_id] ||= mincfile.data_provider.id

    true
  end

  def cluster_commands #:nodoc:
    params       = self.params
    data_type = params[:data_type]

    if data_type == "default"
      data_type = ""
    else
      data_type = "-#{data_type}"
    end

    file_format = params[:file_format]
    file_format = "-#{file_format}"

    [
      "source #{CBRAIN::Quarantine_dir}/init.sh",
      "mnc2nii #{data_type} #{file_format} minc_col.mnc"
    ]
  end

  def save_results #:nodoc:
    params      = self.params
    minc_colid = params[:mincfile_id]
    minc_col   = Userfile.find(minc_colid)
    group_id   = minc_col.group_id

    user_id          = self.user_id
    data_provider.id = params[:data_provider_id]

    out_files = Dir.glob("*.{img,hdr,nii,nia}")
    out_files.each do |file|
      self.addlog(file)
      niifile = SingleFile.new(
        :name             => File.basename(minc_col.cache_full_path,".mnc")+File.extname(file),
        :user_id          => user_id,
        :group_id         => group_id,
        :data_provider_id => data_provider_id,
        :task             => "Mnc2nii"
      )
      niifile.cache_copy_from_local_file(file)
      if niifile.save
        niifile.move_to_child_of(minc_col)
        self.addlog("Saved new Nifti file ")
      else
        self.addlog("Could not save back result file .")
      end
    end
  end

end
