
#
# CBRAIN Project
#
# Bourreau System Checks
#
# Original author: Nicolas Kassis (taken from validation_portal by Pierre Rioux)
#
# $Id$
#

require 'socket'

class BourreauSystemChecks < CbrainChecker

  Revision_info=CbrainFileRevision[__FILE__]

  def self.a050_ensure_proper_cluster_management_layer_is_loaded

    #-----------------------------------------------------------------------------
    puts "C> Loading cluster management SCIR layers..."
    #-----------------------------------------------------------------------------

    # Load the proper class for interacting with the cluster

    myself        = RemoteResource.current_resource
    cluster_type  = myself.cms_class || "(Unset)"
    cluster_class = nil
    case cluster_type
    when "SGE"                     # old keyword
      cluster_class = "ScirSge"
    when "PBS"                     # old keyword
      cluster_class = "ScirPbs"
    when "UNIX"                    # old keyword
      cluster_class = "ScirUnix"
    when "MOAB"                    # old keyword
      cluster_class = "ScirMoab"
    when "SHARCNET"                # old keyword
      cluster_class = "ScirSharcnet"
    when /Scir(\w+)/
      cluster_class = cluster_type
    else
      raise "CBRAIN configuration error: cluster type is set to unknown value '#{cluster_type}' !"
    end
    if cluster_class != cluster_type  # adjust old keywords
      myself.cms_class = cluster_class
      myself.save(true)
    end
    session = myself.scir_session
    rev = session.revision_info.svn_id_pretty_file_rev_author_date # loads it?
    puts "C> \t - Layer for '#{cluster_class}' #{rev} loaded."
  end



  def self.a060_ensure_bourreau_worker_processes_are_reported

    #-----------------------------------------------------------------------------
    puts "C> Reporting Bourreau Worker Processes (if any)..."
    #-----------------------------------------------------------------------------

    # This will reconnect with any and all workers already
    # running, for instance if Bourreau was shut down and the workers
    # were still alive.
    allworkers = WorkerPool.find_pool(BourreauWorker)
    allworkers.each do |worker|
      puts "C> \t - Found worker already running: #{worker.pretty_name} ..."
    end
    if allworkers.size == 0
      puts "C> \t - No worker processes found. It's OK, they'll be started as needed."
    else
      puts "C> \t - Scheduling restart for all of them ..."
      allworkers.stop_workers
    end
  end

  def self.a070_ensure_task_workdirs_are_in_subtrees

    myself        = RemoteResource.current_resource
    gridshare_dir = myself.cms_shared_dir
 
    return unless Dir.exists?(gridshare_dir)

    #-----------------------------------------------------------------------------
    puts "C> Moving Old Task Work Directories..."
    #-----------------------------------------------------------------------------

    local_old_tasks = CbrainTask.where(
      :bourreau_id => myself.id,
      :status      => ( CbrainTask::COMPLETED_STATUS + CbrainTask::FAILED_STATUS ) - CbrainTask::ACTIVE_STATUS,
      :share_wd_tid => nil
    ).where(
      [ "updated_at < ?", 1.week.ago ]  # to be safe...
    ).all.select { |task|
      workdir = task.cluster_workdir
      (! ( workdir.blank?     ) ) &&
      (! ( workdir[0] == "/"  ) ) &&  # very old convention with absolute pathnames... we leave them alone
      (! ( workdir    =~ /\// ) ) &&  # must be a simple basename (old convention)
      Dir.exists?("#{gridshare_dir}/#{workdir}")
    }

    if local_old_tasks.empty?
      puts "C> \t- No task needs updating."
      return true
    else
      puts "C> \t- Found #{local_old_tasks.size} tasks to update."
    end

    # Adjust the tasks
    adj_success = 0 ; adj_fail = 0 ; adj_same = 0
    local_old_tasks.each do |task|
      tid         = task.id
      old_workdir = task.cluster_workdir
      begin
        task.cluster_workdir = nil # to trigger creation of new one
        task.send(:make_cluster_workdir) # create new hashed one; it's protected, thus the send
        new_workdir = task.cluster_workdir
        if old_workdir == new_workdir # security check... if same, just ignore
          adj_same += 1
          next
        end
        Dir.rmdir("#{gridshare_dir}/#{new_workdir}") # this should be a brand new empty dir which we replace...
        File.rename("#{gridshare_dir}/#{old_workdir}", "#{gridshare_dir}/#{new_workdir}")  # ... by this
        adj_success += 1
      rescue => ex
        task.cluster_workdir = old_workdir
        adj_fail += 1
        puts_red "Adjustment exception for #{task.bname_tid} : #{ex.class} #{ex.message}"
      end
      task.update_attributes( :cluster_workdir => task.cluster_workdir ) # just this attribute need to change.
    end

    puts "C> \t- Adjustment of task workdirs: #{adj_success} adjusted, #{adj_fail} failed, #{adj_same} stayed the same."

  end

end
