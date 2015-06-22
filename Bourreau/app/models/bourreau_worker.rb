
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

# Original authors: Pierre Rioux and Anton Zoubarev

#= Bourreau Worker Class
#
#This class implements a worker that manages the CBRAIN queue of tasks.
#This model is not an ActiveRecord class.
class BourreauWorker < Worker

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Tasks that are considered actually active (not necessarily handled by this worker)
  ActiveTasks = [ 'Setting Up', 'Queued', 'On CPU',    # 'New' must NOT be here!
                  'On Hold', 'Suspended',
                  'Post Processing',
                  'Recovering Setup', 'Recovering Cluster', 'Recovering PostProcess', # The Recovering states, not Recover
                  'Restarting Setup', 'Restarting Cluster', 'Restarting PostProcess', # The Restarting states, not Restart
                ]

  # Tasks that are actually moved forward by this worker.
  ReadyTasks = [ 'New', 'Queued', 'On CPU', 'Data Ready',
                 'Recover Setup', 'Recover Cluster', 'Recover PostProcess', # The Recover states, not Recovering
                 'Restart Setup', 'Restart Cluster', 'Restart PostProcess', # The Restart states, not Restarting
               ]

  # Adds "RAILS_ROOT/vendor/cbrain/bin" to the system path.
  def setup
    ENV["PATH"] = Rails.root.to_s + "/vendor/cbrain/bin:" + ENV["PATH"]
    sleep 1+rand(15) # to prevent several workers from colliding
    @zero_task_found = 0 # count the normal scan cycles with no tasks
    @rr = RemoteResource.current_resource
    worker_log.info "#{@rr.class.to_s} code rev. #{@rr.revision_info.svn_id_rev} start rev. #{@rr.info.starttime_revision}"
    @rr_id = @rr.id
    @last_ruby_stuck_check = 20.minutes.ago
    @process_task_list_pid = nil
  end

  # Calls process_task() regularly on any task that is ready.
  def do_regular_work

    # Exit if the Bourreau is dead
    unless is_proxy_alive?
      worker_log.info "Bourreau has exited, so I'm quitting too. So long!"
      self.stop_me
      return false
    end

    # Flush AR caches and trigger Ruby garbage collect
    ActiveRecord::Base.connection.clear_query_cache
    GC.enable; GC.start

    # Check for tasks stuck in Ruby, at most once per 20 minutes
    if @last_ruby_stuck_check < (20.minutes + rand(3.minutes)).ago
      self.check_for_tasks_stuck_in_ruby
      @last_ruby_stuck_check = Time.now
    end

    # Asks the DB for the list of tasks that need handling.
    sleep 1+rand(3)
    worker_log.debug "-----------------------------------------------"

    # The list of tasks, here, contains the minimum number of attributes
    # necessary for us to be able to make a decision as to what to do with them.
    # The full objects are reloaded in process_task() later on.
    tasks_todo_rel = CbrainTask.not_archived
       .where( :status => ReadyTasks, :bourreau_id => @rr_id )
       .select([:id, :type, :user_id, :bourreau_id, :status, :updated_at])
    tasks_todo_count = tasks_todo_rel.count
    worker_log.info "Found #{tasks_todo_count} tasks to handle."

    # Detects and turns on sleep mode. We enter sleep mode once we
    # find no task to process for three normal scan cycles in a row.
    #
    # This sleep mode is triggered when there is nothing to do; it
    # lets our process be responsive to signals while not querying
    # the database all the time for nothing.
    #
    # This mode is reset to normal 'scan' mode when receiving a USR1 signal.
    #
    # After one hour a normal scan is performed again so that there is at least
    # some kind of DB activity; some DB servers close their socket otherwise.
    if tasks_todo_count == 0
      @zero_task_found += 1 # count the normal scan cycles with no tasks
      if @zero_task_found >= 3 # three in a row?
        worker_log.info "No tasks need handling, going to sleep for one hour."
        request_sleep_mode(1.hour + rand(15).seconds)
      end
      return
    end
    @zero_task_found = 0

    # Very recent tasks need to rest a little, so we skip them.
    tasks_todo_rel = tasks_todo_rel.where( [ "updated_at < ?", 20.seconds.ago ] )
    return if ! tasks_todo_rel.exists?

    # Fork a subprocess to do the actual task processing
    @process_task_list_pid = nil # make sure it's unset in child
    @process_task_list_pid = Kernel.fork do
      begin
        $0=$0.to_s.sub(/(BourreauWorker)?/, "SubWorker") + "\0"
        @pretty_name = "SubWorker-#{Process.pid}"
        self.worker_log.prefix = @pretty_name + ": " if self.worker_log.is_a?(LoggerPrefixer)

        worker_log.debug "Invoked for #{tasks_todo_count} tasks."
        process_task_list(tasks_todo_rel)
      rescue => ex
        worker_log.fatal "Exception processing tasklist: #{ex.class.to_s} #{ex.message}\n" + ex.backtrace[0..10].join("\n")
        Kernel.exit!(99) # exit!(), and not exit() # used by parent to know an exception occured.
      end
      worker_log.debug "Exiting properly."
      Kernel.exit!(0) # exit!(), and not exit()
    end

    # Wait for subprocess to finish. BLOCKING!
    worker_log.debug "Waiting for SubWorker-#{@process_task_list_pid}."
    while Process.wait != @process_task_list_pid # in case we get interrupted, we need to loop around the wait!
      sleep 1
    end

    # Check status of subprocess running task list; by convention, 99 is an exception and we must stop
    task_list_exit_status = $?.exitstatus rescue 0
    if task_list_exit_status >= 20
      worker_log.info "Exception raised in SubWorker. Exiting."
      self.stop_me
    end

  rescue SystemCallError, Errno::ECHILD # sometimes triggered by Process.wait
    @process_task_list_pid = nil
  ensure
    @process_task_list_pid = nil
  end

  # Propagate a stop signal to the SubWorker.
  # In the subworker it will do nothing.
  def stop_signal_received_callback #:nodoc:
    if @process_task_list_pid
      worker_log.info "Propagating STOP to subprocess #{@process_task_list_pid}"
      Process.kill('TERM',@process_task_list_pid) rescue nil
    end
  end

  # This method is executed in a subprocess to handle a list
  # of active tasks. The reason a subproces is needed is because
  # of ugly long-term memory leaks that accumulate when ActiveRecord
  # are fetched over and over again.
  def process_task_list(tasks_todo_rel) #:nodoc:
    tasks_todo = tasks_todo_rel.all

    # Adding tasks going to VMs
    tasks_todo_vms = get_vm_tasks_to_handle
    tasks_todo.concat tasks_todo_vms unless tasks_todo_vms.blank?
    worker_log.info "Added #{tasks_todo_vms.size} virtual tasks to the list of tasks to process"
 
    # Partition tasks into two sets: 'decrease activity' and 'increase activity'.
    # Actually, 'decrease' means 'decrease or stay the same', or in other
    # words, 'not increase'.
    by_activity = tasks_todo.hashed_partition do |t|
      (t.status =~ /^(New|Recover.*|Restart.*)$/) ? :increase : :decrease
    end

    # Process all tasks that decrease activity
    # Usually, 'Queued', 'On CPU' or 'Data Ready'
    tasks_todo = by_activity[:decrease] || []
    worker_log.debug "There are #{tasks_todo.size} ready tasks that may decrease activity." if tasks_todo.size > 0
    tasks_todo.shuffle.each do |task|
      timezone = ActiveSupport::TimeZone[task.user.time_zone] rescue Time.zone
      Time.use_zone(timezone) do
        process_task(task) # this can take a long time...
      end
      return if stop_signal_received? # stop everything, return control to framework in order to exit
    end

    # At this point, we process tasks that INCREASE activity, so we'll need
    # to check user and bourreau limits as we proceed.
    tasks_todo = by_activity[:increase] || []
    return if tasks_todo.empty?
    worker_log.debug "There are #{tasks_todo.size} ready tasks that will increase activity."

    # Get limits from meta data store
    @rr.meta.reload # reload limits if needed.
    bourreau_max_tasks = @rr.meta[:task_limit_total].to_i # nil or "" or 0 means infinite

    # Prepare relation for 'active tasks on this Bourreau'
    bourreau_active_tasks = CbrainTask.where( :status => ActiveTasks, :bourreau_id => @rr_id )

    # Group tasks by user and process each sublist of tasks
    by_user  = tasks_todo.group_by { |t| t.user_id }
    user_ids = by_user.keys.shuffle # go through users in random order
    while user_ids.size > 0  # loop for each user
      user_id        = user_ids.pop
      user_max_tasks = @rr.meta["task_limit_user_#{user_id}".to_sym]
      user_max_tasks = @rr.meta[:task_limit_user_default] if user_max_tasks.blank?
      user_max_tasks = user_max_tasks.to_i # nil, "" and "0" means unlimited
      user_tasks     = by_user[user_id].shuffle # go through tasks in random order

      bourreau_limit = false 
      user_limit = false
	
      # Loop for each task
      while user_tasks.size > 0

        # Bourreau global limit.
        # If exceeded, there's nothing more we can do for this cycle of 'do_regular_work'
        if bourreau_max_tasks > 0 # i.e. 'if there is a limit configured'
          bourreau_active_tasks_cnt = bourreau_active_tasks.count
          if bourreau_active_tasks_cnt >= bourreau_max_tasks
            worker_log.info "Bourreau limit: found #{bourreau_active_tasks_cnt} active tasks, but the limit is #{bourreau_max_tasks}. Will only process VM tasks now."
            bourreau_limit = true
          end
        end
	
        # User specific limit.
        # If exceeded, there's nothing more we can do for this user, so we go to the next
        if user_max_tasks > 0 # i.e. 'if there is a limit configured'
          user_active_tasks_cnt = bourreau_active_tasks.where( :user_id => user_id ).count
          if user_active_tasks_cnt >= user_max_tasks
            worker_log.info "User ##{user_id} limit: found #{user_active_tasks_cnt} active tasks, but the limit is #{user_max_tasks}. Will only process VM tasks now."
            user_limit = true
          end
        end
	
        # Alright, move the task along its lifecycle
        task = user_tasks.pop
        if ((user_limit || bourreau_limit) and not task.job_template_goes_to_vm?) then 
          worker_log.info "Skipping non VM task #{task.id} due to reached limit."
          break 
        end
        timezone = ActiveSupport::TimeZone[task.user.time_zone] rescue Time.zone
        Time.use_zone(timezone) do
          process_task(task) # this can take a long time...
        end

        return if stop_signal_received? # stop everything, return control to framework in order to exit

      end # each task
	
      return if stop_signal_received? # stop everything, return control to framework in order to exit

    end # each user

    # This ends this cycle of do_regular_work.

  end


  # This method returns an array containing tasks that may be handled by this physical bourreau
  # Make sure you understand it all before trying to optimize (which is required, see #4763)
  def get_vm_tasks_to_handle #:nodoc:

    #gets VMs available to me
    vms = CbrainTask.not_archived.where(:type => "CbrainTask::StartVM", :bourreau_id => @rr_id, :status => "On CPU")  
    return nil unless vms.blank? || ( vms.size != 0 )

    #gets all tasks going to DiskImage bourreaux
    tasks_for_vms = Array.new
    disk_images = DiskImageBourreau.all
    disk_images.each { |bourreau|
      #list tasks going to these bourreaux
      tasks_for_vms.concat CbrainTask.not_archived.where(:bourreau_id => bourreau.id, :status => ReadyTasks) 
    }

    #now joins
    tasks = Array.new #will contain the new tasks that I could send to my VMs + the tasks that I need to handle

    #add the tasks already on my VMs, unless VM is down
    tasks_for_vms.each { |y| 
      if y.params[:physical_bourreau] == @rr_id && 
	( y.vm_id.blank? || y.status != "On CPU" || CbrainTask.find(y.vm_id).status == "On CPU" ) #5321, #4851
        tasks << y
      end
    }

    # now determines which pending tasks could be taken by my VMs
    vms.each { |x| 
      if x.params[:vm_status] == "booted"
        worker_log.info "=== Found a booted VM: task id = #{x.id}, vm file id = #{x.params[:disk_image]}" 
        job_slots = x.params[:job_slots].to_i 
        worker_log.info "VM #{x.id} has #{job_slots} job slots"
        allTasks = ActiveTasks.dup
        allTasks.concat(ReadyTasks)
        CbrainTask.transaction do
          x.lock! # to prevent different workers to concurrently send tasks to the same VM, potentially more jobs than job slots on the VM. Only the workers of this bourreau will attempt to take this lock
          active_jobs = CbrainTask.where(:vm_id => x.id,:status => allTasks).count
          worker_log.info "VM #{x.id} has #{active_jobs} active jobs"
          free_slots = job_slots - active_jobs
          worker_log.info "VM #{x.id} has #{free_slots} free job slots"
          #add new tasks if free job slots available
          if free_slots > 0 
            #check if a task could go to this booted VM
            tasks_for_vms.each { |y| 
              if y.status == 'New'
                task_image_file_id = DiskImageBourreau.where(:id => y.bourreau_id).first #this should be a find
                worker_log.info "Task #{y.id} needs image file id #{task_image_file_id.disk_image_file_id}"
                if task_image_file_id.disk_image_file_id.to_i == x.params[:disk_image].to_i 
                  if y.vm_id.blank? #don't take a task that someone else took
		    begin
		      cpu_vm = x.get_time_on_cpu
                      if y.job_walltime_estimate < ( x.job_walltime_estimate - cpu_vm ) # don't take tasks that will not fit in the remaining walltime
                        worker_log.info "Task #{y.id} is estimated to last #{y.job_walltime_estimate}. It can fit in the remaining #{x.job_walltime_estimate - x.get_time_on_cpu}s on VM #{x.id}."
                        CbrainTask.transaction do
                          # It's probably nicer to put this update after status transition to "Setting Up" in process_task. But then we'd need to redo VM selection there.
                          y.lock! # to prevent different workers to send this task concurrently to (different) VMs. All workers of all bourreau may try to get this lock.
                          worker_log.info "====> VM task #{y.id} may go to VM #{x.id}"
                          free_slots = free_slots - 1
                          y.params[:physical_bourreau] = @rr_id 
                          y.vm_id = x.id #TODO (VM tristan) check if we really want to fix *now* the VM id where this task will be executed. 
                          tasks << y
                          y.save!
                        end
                      else
                        worker_log.info "Task #{y.id} is estimated to last #{y.job_walltime_estimate}. It cannot fit in the remaining #{x.job_walltime_estimate - x.get_time_on_cpu}s on VM #{x.id}."
                      end
                    rescue => ex
	                worker_log.info "#{ex.message}"
                    end
                  end
                  break unless free_slots > 0
                else
                  worker_log.info "====> VM task #{y.id} may not go to VM #{x.id} (VM disk file id is #{x.params[:disk_image]})"
                end
              end
            }
          end
          x.save
        end
      end          
    }
    return tasks
  end

  # This is the worker method that executes the necessary
  # code to make a task go from state *New* to *Setting* *Up*
  # and from state *Data* *Ready* to *Post* *Processing*.
  #
  # It also updates the statuses from *Queued* to
  # *On* *CPU* and *On* *CPU* to *Data* *Ready* based on
  # the activity on the cluster, but no code is run for
  # these transitions.
  def process_task(task) # when entering this methods task is a partial object, with only a few attributes

    notification_needed = true # set to false later, in the case of restarts and recovers

    task.reload # reloads the task and all its attributes

    initial_status      = task.status
    initial_change_time = task.updated_at

    worker_log.debug "--- Got #{task.bname_tid} in state #{initial_status}"

    unless task.status =~ /^(Recover|Restart)/
      task.update_status 
      new_status = task.status

      worker_log.debug "Updated #{task.bname_tid} to state #{new_status}"

      return if initial_status == 'On CPU' && new_status == 'On CPU'; # nothing else to do

      # Record bourreau delay time for Queued -> On CPU
      if initial_status == 'Queued' && new_status =~ /On CPU|Data Ready/
        task.addlog("State updated to #{new_status}")
        @rr.meta.reload
        n2q = task.meta[:last_delay_new_to_queued] || 0 # task-specific
        q2r = Time.now - initial_change_time
        @rr.meta[:last_delay_new_to_queued]      = n2q.to_i # separate record for bourreau
        @rr.meta[:last_delay_queued_to_running]  = q2r.to_i # separate record for bourreau
        @rr.meta[:latest_in_queue_delay]         = n2q.to_i + q2r.to_i
        @rr.meta[:time_of_latest_in_queue_delay] = Time.now
      end

      # Recored bourreau performance factor for On CPU -> Data ready 
      if initial_status == 'On CPU' && new_status == 'Data Ready' && task.type != "CbrainTask::StartVM"
        # will miss it in case task is too short
        @rr.meta.reload 
        time_on_cpu = Time.now - task.on_cpu_timestamp # was initial_change_time, which was unreliable
        task.addlog "Task spent #{time_on_cpu} on CPU"
        @rr.meta[:latest_performance_factor] = time_on_cpu.to_f / task.job_walltime_estimate.to_f
	begin
          @rr.meta[:time_of_latest_performance_factor] = Time.now
	rescue => ex
	  task.addlog "Cannot set time of latest peformance factor: #{ex.message}" + ex.backtrace[0..10].join("\n")
	end
      end

    end

    case task.status

      #####################################################################
      when 'New'
        action = nil
        if task.share_wd_tid.present?
          workdir = nil
          begin
            workdir = task.full_cluster_workdir
          rescue => ex
            task.addlog("Shared work directory unavailable: #{ex.message}")
            action = :fail
          end
          action ||= (workdir.present? && File.directory?(workdir)) ? nil : :wait # nil means: evaluate further prerequs.
        end
        action ||= task.prerequisites_fulfilled?(:for_setup)
        if action == :go
          # We need to raise an exception if we cannot successfully
          # transition ourselves.
          task.status_transition!("New","Setting Up")
          worker_log.debug "Start   #{task.bname_tid}"
          task.addlog_current_resource_revision
          task.addlog_context(self,"#{self.pretty_name}")
          task.setup_and_submit_job # New -> Queued|Failed To Setup
          worker_log.info  "Submitted: #{task.bname_tid}"
          worker_log.debug "     -> #{task.bname_tid} to state #{task.status}"
          task.meta[:last_delay_new_to_queued] = (Time.now - initial_change_time).to_i
        elsif action == :wait
          worker_log.debug "     -> #{task.bname_tid} unfulfilled Setup prerequisites."
        else # action == :fail
          worker_log.debug "     -> #{task.bname_tid} failed Setup prerequisites."
          task.status_transition(task.status, "Failed Setup Prerequisites")
          task.addlog_context(self,"#{self.pretty_name} detected failed Setup prerequisites")
          task.save
        end

      #####################################################################
      when 'Data Ready'
        action = task.prerequisites_fulfilled?(:for_post_processing)
        if action == :go
          # We need to raise an exception if we cannot successfully
          # transition ourselves.
          task.status_transition!("Data Ready","Post Processing")
          worker_log.debug "PostPro #{task.bname_tid}"
          task.addlog_current_resource_revision
          task.addlog_context(self,"#{self.pretty_name}")
          task.post_process # Data Ready -> Completed|Failed To PostProcess|Failed On Cluster
          worker_log.info  "PostProcess: #{task.bname_tid}"
          worker_log.debug "     -> #{task.bname_tid} to state #{task.status}"
        elsif action == :wait
          worker_log.debug "     -> #{task.bname_tid} unfulfilled PostProcessing prerequisites."
        else # action == :fail
          worker_log.debug "     -> #{task.bname_tid} failed PostProcessing prerequisites."
          task.status_transition(task.status, "Failed PostProcess Prerequisites")
          task.addlog_context(self,"#{self.pretty_name} detected failed PostProcessing prerequisites")
          task.save
        end

      #####################################################################
      when /^Recover (Setup|Cluster|PostProcess)/
        notification_needed = false
        fromwhat = Regexp.last_match[1]
        task.status_transition!(task.status, "Recovering #{fromwhat}")  # 'Recover X' to 'Recovering X'

        # Check special case where we can reconnect to a running task!
        if fromwhat =~ /Cluster|PostProcess/
          clusterstatus = task.send(:cluster_status) rescue nil # this is normally a protected method
          if clusterstatus.blank? # postpone, can't get status
            task.status_transition!(task.status, "Recover #{fromwhat}")  # 'Recovering X' to 'Recover X'
            return
          end
          if clusterstatus.match(/^(On CPU|Suspended|On Hold|Queued)$/)
            task.addlog_context(self,"Woh there Nelly! While attempting recovery from #{fromwhat} failure we found a cluster task still running! Resetting to #{clusterstatus}")
            task.status_transition!(task.status,clusterstatus) # try to update; ignore errors.
            task.save
            return
          end
        end

        # Check if we can recover
        recover_method = nil
        recover_method = :recover_from_setup_failure           if fromwhat == 'Setup'
        recover_method = :recover_from_cluster_failure         if fromwhat == 'Cluster'
        recover_method = :recover_from_post_processing_failure if fromwhat == 'PostProcess'
        canrecover = false
        task.addlog_context(self,"Attempting to run recovery method '#{recover_method}'.")
        begin
          task.addlog_current_resource_revision
          workdir    = task.full_cluster_workdir || ""
          workdir_ok = (! workdir.blank?) && File.directory?(workdir)
          task.addlog("Task work directory invalid or does not exist.") unless workdir_ok
          if ! workdir_ok
            canrecover = (fromwhat == 'Setup' ? true : false)
            task.addlog("But since this was a setup failure, we will simply assume we can move on to 'New'.") if canrecover
          else
            canrecover = Dir.chdir(workdir) do
              task.addlog("Triggering recovery method '#{recover_method}()'.")
              task.send(recover_method)  # custom recovery method written by task programmer
            end
          end
        rescue => ex
          task.addlog_exception(ex,"Recovery method '#{recover_method}' raised an exception:")
          canrecover = false
        end

        # Trigger recovery if all OK
        if !canrecover
          task.addlog("Cannot recover from '#{fromwhat}' failure. Returning task to Failed state.")
          task.status_transition(task.status, "Failed To Setup")       if     fromwhat    == 'Setup'
          task.status_transition(task.status, "Failed On Cluster")     if     fromwhat    == 'Cluster'
          task.status_transition(task.status, "Failed To PostProcess") if     fromwhat    == 'PostProcess'
        else # OK, we have the go ahead to retry the task
          task.addlog("Successful recovery from '#{fromwhat}' failure, now we retry it.")
          if fromwhat == 'Cluster' # special case, we need to resubmit the task.
            begin
              Dir.chdir(task.full_cluster_workdir) do
                task.instance_eval { submit_cluster_job } # will set status to 'Queued' or 'Data Ready'
                # Line above: the eval is needed because it's a protected method, and I want to keep it so.
              end
            rescue => ex
              task.addlog_exception(ex,"Job submit method raised an exception:")
              task.status_transition(task.status, "Failed On Cluster")
            end
          else # simpler cases, we just reset the status and let the task return to main flow.
            task.status_transition(task.status, "New")                    if fromwhat    == 'Setup'
            task.status_transition(task.status, "Data Ready")             if fromwhat    == 'PostProcess'
          end
        end
        task.save

      #####################################################################
      when /^Restart (Setup|Cluster|PostProcess)/
        notification_needed = false
        fromwhat = Regexp.last_match[1]
        task.status_transition!(task.status,"Restarting #{fromwhat}")  # 'Restart X' to 'Restarting X'

        # Check if we can restart
        restart_method = nil
        restart_method = :restart_at_setup                   if fromwhat == 'Setup'
        restart_method = :restart_at_cluster                 if fromwhat == 'Cluster'
        restart_method = :restart_at_post_processing         if fromwhat == 'PostProcess'
        canrestart = false
        task.addlog_context(self,"Attempting to run restart method '#{restart_method}'.")
        begin
          task.addlog_current_resource_revision
          workdir    = task.full_cluster_workdir || ""
          workdir_ok = (! workdir.blank?) && File.directory?(workdir)
          task.addlog("Task work directory invalid or does not exist.") unless workdir_ok
          if ! workdir_ok
            canrestart = false
          else
            canrestart = Dir.chdir(workdir) do
              task.send(restart_method)  # custom restart preparation method written by task programmer
            end
          end
        rescue => ex
          task.addlog_exception(ex,"Restart preparation method '#{restart_method}' raised an exception:")
          canrestart = false
        end

        # Trigger restart if all OK
        if !canrestart
          task.addlog("Cannot restart at '#{fromwhat}'. Returning task status to Completed.")
          task.status_transition(task.status, "Completed")
        else # OK, we have the go ahead to restart the task
          task.run_number = task.run_number + 1
          task.addlog("Preparation for restarting at '#{fromwhat}' succeeded, now we restart it.")
          task.addlog("This task's Run Number was increased to '#{task.run_number}'.")
          if fromwhat == 'Cluster' # special case, we need to resubmit the task.
            begin
              Dir.chdir(task.full_cluster_workdir) do
                task.instance_eval { submit_cluster_job } # will set status to 'Queued' or 'Data Ready'
                # Line above: the eval is needed because it's a protected method, and I want to keep it so.
              end
            rescue => ex
              task.addlog_exception(ex,"Job submit method raised an exception:")
              task.status_transition(task.status, "Failed On Cluster")
            end
          else # simpler cases, we just reset the status and let the task return to main flow.
            task.status_transition(task.status, "New")                    if fromwhat    == 'Setup'
            task.status_transition(task.status, "Data Ready")             if fromwhat    == 'PostProcess'
          end
        end
        task.save

    end # case 'status' is 'New', 'Data Ready', 'Recover*' and 'Restart*'



    #####################################################################
    # Task notification section
    #####################################################################
    notification_needed = false if task.tool && task.tool.category && task.tool.category == 'background'

    if notification_needed # not needed for restarts or recover ops
      if task.status == 'Completed'
        Message.send_message(task.user,
                             :message_type  => :notice,
                             :header        => "Task #{task.name} Completed Successfully",
                             :description   => "Oh great!",
                             :variable_text => "[[#{task.bname_tid}][/tasks/#{task.id}]]"
                            )
      elsif task.status =~ /^Failed/
        Message.send_message(task.user,
                             :message_type  => :error,
                             :header        => "Task #{task.name} #{task.status}",
                             :description   => "Sorry about that. Check the task's log.\n" +
                                               "Consider using the 'Recovery' button to try the task again, in case\n" +
                                               "it's just a system error: CBRAIN will do its best to fix it.",
                             :variable_text => "[[#{task.bname_tid}][/tasks/#{task.id}]]"
                            )
      end
    end


  # A CbrainTransitionException can occur just before we try
  # setup_and_submit_job() or post_process(); it's allowed, it means
  # some other worker has beaten us to the punch. So we just ignore it.
  rescue CbrainTransitionException => te
    worker_log.debug "Transition Exception: task '#{task.bname_tid}' FROM='#{te.from_state}' TO='#{te.to_state}' FOUND='#{te.found_state}'"
    return

  # Any other error is critical and fatal; we're already
  # trapping all exceptions in setup_and_submit_job() and post_process(),
  # so if an exception went through anyway, it's a CODING BUG
  # in this worker's logic.
  rescue Exception => e
    worker_log.fatal "Exception processing task #{task.bname_tid}: #{e.class.to_s} #{e.message}\n" + e.backtrace[0..10].join("\n")
    raise e
  end

  # As a side effect of the regular checks, detect some
  # tasks stuck in Ruby code and mark them as failed.
  def check_for_tasks_stuck_in_ruby
    stucked = CbrainTask.where(:status => CbrainTask::RUBY_STATUS, :bourreau_id => @rr_id).where("updated_at < ?",8.hours.ago)
    stucked.each do |task|
      orig_status = task.status
      task.mark_as_failed_in_ruby rescue nil
      if task.status != orig_status
        task.addlog("Worker detects that task is too old and stuck at '#{orig_status}'; status reset to '#{task.status}'")
        worker_log.info "Stuck: #{task.bname_tid} from #{orig_status} to state #{task.status}"
      end
    end
  end

end
