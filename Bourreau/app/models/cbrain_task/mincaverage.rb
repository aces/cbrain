
#
# CBRAIN Project
#
# CbrainTask subclass for running mincaverage
#
# Original author: Tarek Sherif
#   base on template by Pierre Rioux
#
# $Id$
#

#A subclass of CbrainTask::ClusterTask to run mincaverage.
class CbrainTask::Mincaverage < CbrainTask::ClusterTask

  Revision_info="$Id$"

  include RestartableTask # This task is naturally restartable
  include RecoverableTask # This task is naturally recoverable

  def setup #:nodoc:
    params       = self.params
    filelist  = params[:interface_userfile_ids]
    filelist.each do |mincfile_id|
      mincfile     = Userfile.find(mincfile_id)
      unless mincfile
        self.addlog("Could not find active record entry for userfile #{mincfile_id}")
        return false
      end
      mincfile.sync_to_cache
      cachename    = mincfile.cache_full_path.to_s
      safe_symlink(cachename, mincfile.name)  
      params[:data_provider_id] = mincfile.data_provider_id if params[:data_provider_id].blank? # first mincfile decides destination?
    end

    params[:out_name] ||= "average_#{Time.now.to_i}.mnc"

    true
  end

  def cluster_commands #:nodoc:
    params       = self.params
    file_names  = Userfile.find(params[:interface_userfile_ids]).map(&:name).join(" ")
    
    out_name = params[:out_name]
    normalize = params[:normalize].blank? ? "-nonormalize" : "-normalize"
    copy_header = params[:copy_header].blank? ? "-nocopy_header" : "-copy_header"
    avg_dim = params[:avg_dim].blank? ? "" : "-avgdim #{params[:avg_dim]}"
    sdfile = params[:sdfile].blank? ? "" : "-sdfile sd_#{out_name}"
    weights = params[:weights].blank? ? "" : "-weights #{params[:interface_userfile_ids].map{|id| params[:weights][id.to_s]}.join(",")}"
            
    [
      "source #{CBRAIN::Quarantine_dir}/init.sh",
      "mincaverage #{file_names} #{out_name} #{normalize} #{copy_header} #{avg_dim} #{sdfile} #{weights}",
    ]
  end

  def save_results #:nodoc:
    params       = self.params
    user_id      = self.user_id
    user         = User.find(user_id)
    group_id     = SystemGroup.find_by_name(user.login).id
    out_name     = params[:out_name]
    

    unless (File.exists?(out_name))
      self.addlog("Could not find result file #{out_name}.")
      return false
    end


    outfile = safe_userfile_find_or_new(SingleFile,
      :name             => out_name,
      :user_id          => user_id,
      :group_id         => group_id,
      :data_provider_id => params[:data_provider_id],
      :task             => "Mincaverage"
    )
    outfile.cache_copy_from_local_file(out_name)
    outfile_success = outfile.save
    if outfile_success
      self.addlog("Saved new average file #{out_name}")
    else
      self.addlog("Could not save back result file '#{out_name}'.")
    end
    
    if params[:sdfile]
      sdfile = safe_userfile_find_or_new(SingleFile,
        :name             => "sd_#{out_name}",
        :user_id          => user_id,
        :group_id         => group_id,
        :data_provider_id => params[:data_provider_id],
        :task             => "Mincaverage"
      )
      sdfile.cache_copy_from_local_file("sd_#{out_name}")
      sdfile_success = sdfile.save
      if sdfile_success
        self.addlog("Saved new standard deviation file sd_#{out_name}")
      else
        self.addlog("Could not save back standard deviation file 'sd_#{out_name}'.")
      end
      return outfile_success && sdfile_success
    else
      return outfile_success
    end
  end

end

