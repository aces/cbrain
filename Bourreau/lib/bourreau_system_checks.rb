
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.  
#

require 'socket'

class BourreauSystemChecks < CbrainChecker #:nodoc:

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.puts(*args) #:nodoc:
    Rails.logger.info("\e[33m" + args.join("\n") + "\e[0m") rescue nil
    Kernel.puts(*args)
  end

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
    puts "C> \t- Layer for '#{cluster_class}' #{rev} loaded."
  end



  def self.a060_ensure_bourreau_worker_processes_are_reported

    #-----------------------------------------------------------------------------
    puts "C> Reporting Bourreau Worker processes (if any)..."
    #-----------------------------------------------------------------------------

    # This will reconnect with any and all workers already
    # running, for instance if Bourreau was shut down and the workers
    # were still alive.
    allworkers = WorkerPool.find_pool(BourreauWorker)
    allworkers.each do |worker|
      puts "C> \t- Found worker already running: #{worker.pretty_name} ..."
    end
    if allworkers.size == 0
      puts "C> \t- No worker processes found. It's OK, they'll be started as needed."
    else
      puts "C> \t- Scheduling restart for all of them ..."
      allworkers.stop_workers
    end

    # Note: we cannot start the workers here because
    # the current process will disappear once the HTTP server
    # forks, and the workers want their parent to keep
    # existing. A separate 'start_workers' command must
    # be sent to the control channel explicitely later on.

  end



  def self.a070_ensure_task_workdirs_are_in_subtrees

    myself        = RemoteResource.current_resource
    gridshare_dir = myself.cms_shared_dir
 
    return unless Dir.exists?(gridshare_dir)

    #-----------------------------------------------------------------------------
    puts "C> Moving and validating old task work directories..."
    #-----------------------------------------------------------------------------

    local_old_tasks = CbrainTask.where(
      :bourreau_id  => myself.id,
      :status       => ( CbrainTask::COMPLETED_STATUS + CbrainTask::FAILED_STATUS ) - CbrainTask::ACTIVE_STATUS,
      :share_wd_tid => nil
    ).where(
      [ "updated_at < ?", 1.week.ago ], # just to be safe...
    ).where(
      "cluster_workdir IS NOT NULL"
    ).where(
      "( cluster_workdir LIKE \"/%\" or cluster_workdir NOT LIKE \"%%/%\" )"
    ).all

    if local_old_tasks.empty?
      puts "C> \t- No task needs updating."
      return true
    else
      puts "C> \t- Found #{local_old_tasks.size} tasks to update."
    end

    # Adjust the tasks
    adj_success = 0 ; adj_fail = 0 ; adj_same = 0 ; adj_zap = 0
    local_old_tasks.each_with_index do |task,idx|
      tid          = task.id
      old_workdir  = task.cluster_workdir
      last_updated = task.updated_at || Time.now
      #puts_red "OLD=#{old_workdir}"
      puts "C> \t- Updating task ##{idx+1} ..." if (idx+1) % 50 == 0

      next if old_workdir.blank? # should not even happen

      # Bad entry? Just zap.
      full = task.full_cluster_workdir({}, { :cms_shared_dir => gridshare_dir })
      if ! Dir.exists?(full)
        adj_zap += 1
        task.update_attribute( :cluster_workdir, nil                  ) # just this attribute need to change.
        task.update_attribute( :updated_at,      last_updated         ) # to restore the original update date
        next
      end

      # If it was full path in form "gridshare_dir/taskworkdir"
      if old_workdir.index(gridshare_dir) == 0
        old_workdir[0,gridshare_dir.size + 1] = "" # pretend it was just "taskworkdir"
      end

      next if old_workdir.blank? || old_workdir =~ /\// # Strange. Should never happen unless attribute contained WEIRD path

      # Adjust the pure basename cases
      begin
        task.cluster_workdir = nil # to trigger creation of new one
        task.send(:make_cluster_workdir) # create new hashed one; it's protected, thus the send
        new_workdir = task.cluster_workdir
        if old_workdir == new_workdir # security check... if same, just ignore; should never happen!
          adj_same += 1
          next
        end
        #puts_green "Adj #{old_workdir} -> #{new_workdir}"
        Dir.rmdir("#{gridshare_dir}/#{new_workdir}") # this should be a brand new empty dir which we replace...
        File.rename("#{gridshare_dir}/#{old_workdir}", "#{gridshare_dir}/#{new_workdir}")  # ... by this
        adj_success += 1
      rescue => ex
        task.cluster_workdir = old_workdir
        adj_fail += 1
        puts_red "Adjustment exception for #{task.bname_tid} : #{ex.class} #{ex.message}"
      end
      task.update_attribute( :cluster_workdir, task.cluster_workdir ) # just this attribute need to change.
      task.update_attribute( :updated_at,      last_updated         ) # to restore the original update date
    end

    puts "C> \t- Adjustment of task workdirs: #{adj_success} adjusted, #{adj_fail} failed, #{adj_zap} zapped, #{adj_same} stayed the same."

  end



  def self.a075_ensure_task_workdirs_still_exist

    myself        = RemoteResource.current_resource
    gridshare_dir = myself.cms_shared_dir
 
    return unless Dir.exists?(gridshare_dir)

    #-----------------------------------------------------------------------------
    puts "C> Making sure work directories for local tasks exist..."
    #-----------------------------------------------------------------------------

    local_tasks_with_workdirs = CbrainTask.real_tasks.wd_present.not_shared_wd.where(
      :bourreau_id  => myself.id,
      #[ "updated_at < ?", 3.hours.ago ], # just to be safe...
    )

    num_to_check = local_tasks_with_workdirs.count
    return if num_to_check == 0
    puts "C> \t- #{num_to_check} tasks to check (in background)..."

    CBRAIN.spawn_with_active_records(User.admin, "TaskWorkdirCheck") do
      bad_tasks = []
      local_tasks_with_workdirs.all.each do |task|
        full = task.full_cluster_workdir({}, { :cms_shared_dir => gridshare_dir })
        next if Dir.exists?(full)
        bad_tasks << task.tname_tid
        task.cluster_workdir      = nil
        task.cluster_workdir_size = nil
        task.workdir_archived     = false if task.workdir_archive_userfile_id.blank?
        task.save
      end

      if bad_tasks.size > 0
        Rails.logger.info "Adjusted #{bad_tasks.size} tasks with missing work directories."
        Message.send_message(User.admin,
          :type          => :system,
          :header        => "Report of task workdir disappearances on '#{myself.name}'",
          :description   => "Some work directories of tasks have disappeared.",
          :variable_text => "Number of tasks: #{bad_tasks.size}\n" +
                            "List of tasks:\n#{bad_tasks.join("\n")}\n",
          :critical      => true,
          :send_email    => false
        ) rescue true
      end
    end

  end



  def self.a080_ensure_tasks_have_workdir_sizes

    #-----------------------------------------------------------------------------
    puts "C> Refreshing the disk sizes for workdirs of CbrainTasks..."
    #-----------------------------------------------------------------------------

    myself        = RemoteResource.current_resource
    gridshare_dir = myself.cms_shared_dir
 
    if gridshare_dir.blank? || ! Dir.exists?(gridshare_dir)
      puts "C> \t- SKIPPING! No task work directory yet configured!"
      return
    end

    local_tasks_not_sized = CbrainTask.where(
      :bourreau_id          => myself.id,
      :status               => ( CbrainTask::COMPLETED_STATUS + CbrainTask::FAILED_STATUS ) - CbrainTask::ACTIVE_STATUS,
      :cluster_workdir_size => nil,
    ).where(
      [ "updated_at < ?", 1.day.ago ], # just to be safe...
    ).where(
      "cluster_workdir IS NOT NULL"
    )

    how_many = local_tasks_not_sized.count
    if how_many == 0
      puts "C> \t- No tasks need to be adjusted."
      return
    end

    puts "C> \t- Refreshing sizes for #{how_many} tasks (in background)..."

    CBRAIN.spawn_with_active_records(User.admin, "TaskSizes") do
      totsize = 0
      totnils = 0
      local_tasks_not_sized.all.each do |task|
        size     = task.send(:update_size_of_cluster_workdir) rescue nil # it's a protected method
        totsize += size if size
        totnils += 1    if size.nil?
      end
      Rails.logger.info "Adjusted #{local_tasks_not_sized.size} tasks, #{totsize} bytes, #{totnils} skipped."
      Message.send_message(User.admin,
        :type          => :system,
        :header        => "Report of task sizes refresh on '#{myself.name}'",
        :description   => "The disk space used by some tasks needed to be recomputed.",
        :variable_text => "Report:\n" +
                          "Number of tasks: #{local_tasks_not_sized.size}\n" +
                          "Total size     : #{totsize} bytes\n" +
                          "Tasks skipped  : #{totnils} tasks",
        :critical      => true,
        :send_email    => false
      ) rescue true
    end

  end



  def self.z000_ensure_we_have_a_forwarded_ssh_agent

    #----------------------------------------------------------------------------
    puts "C> Making sure the portal is forwarding a SSH agent to us..."
    #----------------------------------------------------------------------------

    agent = SshAgent.find_forwarded.try(:aliveness)
    if agent
      puts "C> \t- Found a forwarded agent on SOCK=#{agent.socket}"
      agent.apply
    else
      puts "C> \t- WARNING: no forwarded agent detected! Hope you exchanged all the SSH keys instead!"
    end

  end

end

