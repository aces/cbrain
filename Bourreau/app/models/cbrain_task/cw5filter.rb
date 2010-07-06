
#
# CBRAIN Project
#
# CbrainTask subclass; this file is a TEMPLATE for creating a
# new processing class.
#
# Original author: Mathieu Desrosiers
# => base on template by Pierre Rioux
# $Id$
#

#A subclass of ClusterTask to run cw5filter.
class CbrainTask::Cw5filter < ClusterTask

  Revision_info="$Id$"

  include RestartableTask # This task is naturally restartable
  include RecoverableTask # This task is naturally recoverable

  def setup #:nodoc:
    params       = self.params
    user_id      = self.user_id

    input_file_id  = params[:file_ids]
    input_file = Userfile.find(input_file_id)
    
    unless input_file
      self.addlog("Could not find active record entry for userfile #{input_file_id}")
      return false
    end
    
    input_file.sync_to_cache
    cachename    = input_file.cache_full_path.to_s

    params[:data_provider_id] = input_file.data_provider_id if params[:data_provider_id].blank?
    
    safe_symlink(cachename, input_file.name)
    
    #filter and probe prabably dont need all those extra overhead, need I discussion with pierre.

    probe_id  = params[:probe_id]
    probe_file = Userfile.find(probe_id)
    unless probe_file
      self.addlog("Could not find active record entry for userfile #{probe_id}")
      return false
    end
    probe_file.sync_to_cache
    cachename    = probe_file.cache_full_path.to_s
    safe_symlink(cachename, "probe.mls") #I What the name in a variable instead 
     
    filter_id  = params[:filter_id]
    filter_file = Userfile.find(filter_id)
    unless filter_file
      self.addlog("Could not find active record entry for userfile #{filter_id}")
      return false
    end
    filter_file.sync_to_cache
    cachename    = filter_file.cache_full_path.to_s
    safe_symlink(cachename, "filter.flt") #I What the name in a variable instead 
    
    true
  end

  def cluster_commands #:nodoc:
    params       = self.params
    user_id      = self.user_id
 
    input_file_id  = params[:file_ids]
    input_file = Userfile.find(input_file_id)
    out_name =  File.basename(input_file.name, ".bin") + ".cw5"
    params[:out_name] = out_name 
    
    unless input_file
      self.addlog("Could not find active record entry for userfile #{input_file_id}")
      return false
    end
    
    [
      "source #{CBRAIN::Quarantine_dir}/init.sh",
      "cw5filter -o #{out_name} -p probe.mls -f filter.flt #{input_file.name}"
    ]  
    
  end

  def save_results #:nodoc:
    params       = self.params
    user_id      = self.user_id
    out_name = params[:out_name]

    input_file_id  = params[:file_ids]
    input_file = Userfile.find(input_file_id)


    unless (File.exists?(out_name))
      self.addlog("Could not find result file #{out_name}.")
      return false
    end

    outfile = safe_userfile_find_or_new(SingleFile,
      :name             => out_name,
      :user_id          => user_id,
      :group_id         => input_file.group_id, 
      :data_provider_id => params[:data_provider_id],
      :task             => 'CW5filter'
    )
    outfile.cache_copy_from_local_file(out_name)

    if outfile.save
      outfile.move_to_child_of(input_file)
      self.addlog("Saved new cw5 file #{out_name}")
      return true
    else
      self.addlog("Could not save back result file '#{out_name}'.")
      params.delete(:opticresult_id)
      return false
    end
    
    input_file_id  = params[:file_ids]
    input_file = Userfile.find(input_file_id)

    params[:opticresult_id] = outfile.id
    self.addlog_to_userfiles_these_created_these([input_file],[outfile])
    
    true
  end

end

