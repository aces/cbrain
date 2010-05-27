
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

#A subclass of CbrainTask::ClusterTask to run mincmath.
class CbrainTask::Mincmath < CbrainTask::ClusterTask

  Revision_info="$Id$"

  def setup #:nodoc:
    params    = self.params
    filelist  = params[:filelist].values
    filelist.each do |mincfile_id|
      mincfile     = Userfile.find(mincfile_id)
      unless mincfile
        self.addlog("Could not find active record entry for userfile #{mincfile_id}")
        return false
      end
      mincfile.sync_to_cache
      cachename    = mincfile.cache_full_path.to_s
      File.symlink(cachename, mincfile.name)
      params[:data_provider_id] ||= mincfile.data_provider.id  # first mincfile decides destination?
    end 
    true
  end

  def cluster_commands #:nodoc:
    params       = self.params

    file_names  = Userfile.find(params[:filelist].values).map(&:name).join(" ")
    
    mincmath_args= {}
    add =""
    no_check_d =""

    add = params[:add] ? "-add" : ""
    no_check_d = params[:nocheck_dimensions] ? "-nocheck_dimensions" : ""
    
    out_name = params[:out_name]
    self.addlog("Here we go mincmath #{add} #{params[:nocheck_dimensions]} #{file_names} #{out_name}")

    [
      "source #{CBRAIN::Quarantine_dir}/init.sh",
      "mincmath #{add} #{no_check_d} #{file_names} #{out_name}",
      "true"
    ]
  end

  def save_results #:nodoc:
  params       = self.params
    user_id      = self.user_id
    user         = User.find(user_id)
    group_id     = SystemGroup.find_by_name(user.login).id
    out_name = params[:out_name]
    

    unless (File.exists?(out_name))
      self.addlog("Could not find result file #{out_name}.")
      return false
    end

    outfile = SingleFile.new(
      :name             => out_name,
      :user_id          => user_id,
      :group_id         => group_id,
      :data_provider_id => params[:data_provider_id],
      :task             => "Mincmath"
    )
    outfile.cache_copy_from_local_file(out_name)
    if outfile.save
      self.addlog("Saved new mincmath file #{out_name}")
      return true
    else
      self.addlog("Could not save back result file '#{out_name}'.")
      return false
    end
  end

end

