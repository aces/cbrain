
#
# CBRAIN Project
#
# CbrainTask subclass for running mincmath
#
# Original author:
# Template author: Pierre Rioux
#
# $Id$
#

#A subclass of CbrainTask::ClusterTask to run mincresample.
class CbrainTask::Mincresample < CbrainTask::ClusterTask

  Revision_info="$Id$"

  include RestartableTask # This task is naturally restartable
  include RecoverableTask # This task is naturally recoverable

  def setup #:nodoc:
    params = self.params
    mincfile_id = params[:mincfile_id] 
    mincfile = Userfile.find(mincfile_id)
    unless mincfile
      self.addlog("Could not find active record entry for userfile #{mincfile_id}")
      return false
    end
    mincfile.sync_to_cache
    safe_symlink(mincfile.cache_full_path.to_s, mincfile.name)

    params[:data_provider_id] = mincfile.data_provider_id if params[:data_provider_id].blank?

    if(params[:transformation_id])
      process_input_files(params[:transformation_id])
    end
    
    if(params[:like_id])
      process_input_files(params[:like_id])
    end
     
    true
  end

  #Sync the transformation or like file to this
  #Bourreau's cache.
  def process_input_files(id) #:nodoc:
    filename = Userfile.find(id)
    unless filename
      self.addlog("Could not find active record entry for userfile #{filename}")
      return false
    end
    filename.sync_to_cache
    safe_symlink(filename.cache_full_path.to_s, filename.name)
  end

  def cluster_commands #:nodoc:
    params       = self.params
    user_id      = self.user_id
    
    mincfile_name  = Userfile.find(params[:mincfile_id]).name
    like_file      = params[:like_id]
    transformation_file = params[:transformation_id]

    resample_tid =""
    resample_like =""
    
    resample_sinc = params[:sinc] ? "-sinc" : ""
   
    resample_t = params[:transformation] ? " -tfm_input_sampling" : ""
    
    unless transformation_file.blank?
      transformation_name = Userfile.find(transformation_file).name
      resample_tid = "-transformation #{transformation_name}"
    end

    unless like_file.blank?
      like_name = Userfile.find(like_file).name
      resample_like = "-like #{like_name}"
    end

    out_name = params[:out_name]

    self.addlog("mincresample #{resample_sinc} #{resample_tid} #{resample_like} #{resample_t} #{mincfile_name} #{out_name}")
    [
      "source #{CBRAIN::Quarantine_dir}/init.sh",
      "mincresample #{resample_sinc} #{resample_tid} #{resample_like} #{resample_t} #{mincfile_name} #{out_name}",
      "true"
    ]
  end

  def save_results #:nodoc:
    params       = self.params
    user_id      = self.user_id
    mincfile_id = params[:mincfile_id] 
    mincfile = Userfile.find(mincfile_id)
    group_id = mincfile.group_id
    out_name = params[:out_name]
    

    unless (File.exists?(out_name))
      self.addlog("Could not find result file #{out_name}.")
      return false
    end

    outfile = safe_userfile_find_or_new(SingleFile,
      :name             => out_name,
      :user_id          => user_id,
      :group_id         => group_id,
      :data_provider_id => params[:data_provider_id],
      :task             => "Mincresample"
    )
    outfile.cache_copy_from_local_file(out_name)

    if outfile.save
      outfile.move_to_child_of(Userfile.find(params[:mincfile_id]))
      self.addlog("Saved new mincresample file #{out_name}")
      return true
    else
      self.addlog("Could not save back result file '#{out_name}'.")
      return false
    end
  end

end


