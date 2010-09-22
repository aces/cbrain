
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

#A subclass of ClusterTask to run mincmath.
class CbrainTask::Mincmath < ClusterTask

  Revision_info="$Id$"

  include RestartableTask # This task is naturally restartable
  include RecoverableTask # This task is naturally recoverable

  def setup #:nodoc:
    params    = self.params
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

    params[:out_name] ||= "mincmath_#{Time.now.to_i}.mnc"

    true
  end

  def cluster_commands #:nodoc:
    params       = self.params
    out_name     = params[:out_name]

    file_names  = Userfile.find(params[:interface_userfile_ids]).map(&:name).join(" ")
    
    mincmath_args= {}
    add =""
    no_check_d =""

    add = params[:add] ? "-add" : ""
    no_check_d = params[:nocheck_dimensions] ? "-nocheck_dimensions" : ""
    
    self.addlog("Here we go mincmath #{add} #{params[:nocheck_dimensions]} #{file_names} #{out_name}")

    [
      "mincmath #{add} #{no_check_d} #{file_names} #{out_name}",
      "true"
    ]
  end

  def save_results #:nodoc:
    params       = self.params
    out_name     = params[:out_name]
    

    unless (File.exists?(out_name))
      self.addlog("Could not find result file '#{out_name}'.")
      return false
    end

    outfile = safe_userfile_find_or_new(SingleFile,
      :name             => out_name,
      :data_provider_id => params[:data_provider_id],
      :task             => "Mincmath"
    )
    outfile.cache_copy_from_local_file(out_name)
    if outfile.save
      self.addlog("Saved new mincmath file #{out_name}")
      params[:outfile_id] = outfile.id
      self.addlog_to_userfiles_these_created_these(Userfile.find(params[:interface_userfile_ids]), [ outfile ])
      return true
    else
      self.addlog("Could not save back result file '#{out_name}'.")
      params.delete(:outfile_id)
      return false
    end
  end

end

