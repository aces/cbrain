
#
# CBRAIN Project
#
# This class implements a worker that manages the CBRAIN queue of tasks.
#
# Original authors: Pierre Rioux and Anton Zoubarev
#
# $Id$
#

#= Bourreau Worker Class
#
#This class implements a worker that manages the CBRAIN queue of tasks.
#This model is not an ActiveRecord class.
class BourreauWorker < Worker

  Revision_info="$Id$"

  # Adds "RAILS_ROOT/vendor/cbrain/bin" to the system path.
  def setup
    ENV["PATH"] = RAILS_ROOT + "/vendor/cbrain/bin:" + ENV["PATH"]
    sleep 1+rand(15) # to prevent several workers from colliding
    @zero_task_found = 0 # count the normal scan cycles with no tasks
  end

  # Calls process_task() regularly on any task that is active.
  def do_regular_work

    # Exit if the Bourreau is dead
    unless is_proxy_alive?
      worker_log.info "Bourreau has exited, so I'm quitting too. So long!"
      self.stop_me
      return false
    end

    # Asks the DB for the list of tasks that need handling.
    sleep 1+rand(3)
    worker_log.debug "Finding list of active tasks."
    tasks_todo = CbrainTask.find(:all,
      :conditions => { :status      => [ 'New', 'Queued', 'On CPU', 'Data Ready',
                                         'Recover Setup', 'Recover Cluster', 'Recover PostProcess',
                                         'Restart Setup', 'Restart Cluster', 'Restart PostProcess',
                                       ],
                       :bourreau_id => CBRAIN::SelfRemoteResourceId } )
    worker_log.info "Found #{tasks_todo.size} tasks to handle."

    # Detects and turns on sleep mode.
    # This sleep mode is triggered when there is nothing to do; it
    # lets our process be responsive to signals while not querying
    # the database all the time for nothing.
    # This mode is reset to normal 'scan' mode when receiving a USR1 signal.
    # After one hour a normal scan is performed again so that there is at least
    # some kind of DB activity; some DB servers close their socket otherwise.
    # We enter sleep mode once we find no task to process for three normal
    # scan cycles in a row.
    if tasks_todo.size == 0
      @zero_task_found += 1 # count the normal scan cycles with no tasks
      if @zero_task_found >= 3 # three in a row?
        @zero_task_found = 0
        worker_log.info "No tasks need handling, going to sleep for one hour."
        request_sleep_mode(1.hour + rand(15).seconds)
      end
      return
    end
    @zero_task_found = 0

    # Processes each task in the active list
    by_user = tasks_todo.group_by { |t| t.user_id }
    user_ids = by_user.keys.shuffle # go through users in random order
    while user_ids.size > 0
      user_id    = user_ids.pop
      task_group = by_user[user_id].shuffle # go through tasks in random order
      while task_group.size > 0
        task               = task_group.pop
        process_task(task) unless task.updated_at > 20.seconds.ago # this can take a long time...
        break if stop_signal_received?
      end # each task
      break if stop_signal_received?
    end # each user

  end

  # This is the worker method that executes the necessary
  # code to make a task go from state *New* to *Setting* *Up*
  # and from state *Data* *Ready* to *Post* *Processing*.
  #
  # It also updates the statuses from *Queued* to
  # *On* *CPU* and *On* *CPU* to *Data* *Ready* based on
  # the activity on the cluster, but no code is run for
  # these transitions.
  def process_task(task)

    mypid = Process.pid
    notification_needed = true # set to false for restarts and recovers

    worker_log.debug "--- Got #{task.bname_tid} in state #{task.status}"

    unless task.status =~ /^(Recover|Restart)/
      task.update_status
      worker_log.debug "Updated #{task.bname_tid} to state #{task.status}"
    end

    case task.status

      #####################################################################
      when 'New'
        action = task.prerequisites_fulfilled?(:for_setup)
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
        elsif action == :wait
          worker_log.debug "     -> #{task.bname_tid} unfulfilled Setup prerequisites."
        else # action == :fail
          worker_log.debug "     -> #{task.bname_tid} failed Setup prerequisites."
          task.status = "Failed Setup Prerequisites"
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
          task.status = "Failed PostProcess Prerequisites"
          task.addlog_context(self,"#{self.pretty_name} detected failed PostProcessing prerequisites")
          task.save
        end

      #####################################################################
      when /^Recover (\S+)/
        notification_needed = false
        fromwhat = Regexp.last_match[1]
        task.status_transition!(task.status,"Recovering #{fromwhat}")  # 'Recover X' to 'Recovering X'
        recover_method = nil
        recover_method = :recover_from_setup_failure           if fromwhat == 'Setup'
        recover_method = :recover_from_cluster_failure         if fromwhat == 'Cluster'
        recover_method = :recover_from_post_processing_failure if fromwhat == 'PostProcess'
        canrecover = false
        task.addlog_context(self,"Attempting to run recovery method '#{recover_method}'.")
        begin
          task.addlog_current_resource_revision
          canrecover = task.send(recover_method)  # custom recovery method written by task programmer
        rescue => ex
          task.addlog_exception(ex,"Recovery method '#{recover_method}' raised an exception:")
          canrecover = false
        end
        if !canrecover
          task.addlog("Cannot recover from '#{fromwhat}' failure. Returning task to Failed state.")
          task.status = "Failed To Setup"       if     fromwhat    == 'Setup'
          task.status = "Failed On Cluster"     if     fromwhat    == 'Cluster'
          task.status = "Failed To PostProcess" if     fromwhat    == 'PostProcess'
          task.status = "Failed UNKNOWN!"       unless task.status =~ /^Failed/ # should never happen
        else # OK, we have the go ahead to retry the task
          task.addlog("Successful recovery from '#{fromwhat}' failure, now we retry it.")
          if fromwhat == 'Cluster' # special case, we need to resubmit the task.
            begin
              Dir.chdir(task.cluster_workdir) do
                task.instance_eval { submit_cluster_job } # will set status to 'Queued' or 'Data Ready'
                # Line above: the eval is needed because it's a protected method, and I want to keep it so.
              end
            rescue => ex
              task.addlog_exception(ex,"Job submit method raised an exception:")
              task.status = "Failed On Cluster"
            end
          else # simpler cases, we just reset the status and let the task return to main flow.
            task.status = "New"                    if fromwhat    == 'Setup'
            task.status = "Data Ready"             if fromwhat    == 'PostProcess'
            task.status = "Failed UNKNOWN!"        if task.status =~ /^Recover/ # should never happen
          end
        end
        task.save

      #####################################################################
      when /^Restart (\S+)/
        notification_needed = false
        fromwhat = Regexp.last_match[1]
        task.status_transition!(task.status,"Restarting #{fromwhat}")  # 'Restart X' to 'Restarting X'
        restart_method = nil
        restart_method = :restart_at_setup                   if fromwhat == 'Setup'
        restart_method = :restart_at_cluster                 if fromwhat == 'Cluster'
        restart_method = :restart_at_post_processing         if fromwhat == 'PostProcess'
        canrestart = false
        task.addlog_context(self,"Attempting to run restart method '#{restart_method}'.")
        begin
          task.addlog_current_resource_revision
          canrestart = task.send(restart_method)  # custom restart preparation method written by task programmer
        rescue => ex
          task.addlog_exception(ex,"Restart preparation method '#{restart_method}' raised an exception:")
          canrestart = false
        end
        if !canrestart
          task.addlog("Cannot restart at '#{fromwhat}'. Returning task status to Completed.")
          task.status = "Completed"
        else # OK, we have the go ahead to restart the task
          task.run_number = task.run_number + 1
          task.addlog("Preparation for restarting at '#{fromwhat}' succeeded, now we restart it.")
          task.addlog("This task's Run Number was increased to '#{task.run_number}'.")
          if fromwhat == 'Cluster' # special case, we need to resubmit the task.
            begin
              Dir.chdir(task.cluster_workdir) do
                task.instance_eval { submit_cluster_job } # will set status to 'Queued' or 'Data Ready'
                # Line above: the eval is needed because it's a protected method, and I want to keep it so.
              end
            rescue => ex
              task.addlog_exception(ex,"Job submit method raised an exception:")
              task.status = "Failed On Cluster"
            end
          else # simpler cases, we just reset the status and let the task return to main flow.
            task.status = "New"                    if fromwhat    == 'Setup'
            task.status = "Data Ready"             if fromwhat    == 'PostProcess'
            task.status = "Failed UNKNOWN!"        if task.status =~ /^Restart/ # should never happen
          end
        end
        task.save

    end # case 'status' is 'New', 'Data Ready', 'Recover*' and 'Restart*'



    #####################################################################
    # Task notification section
    #####################################################################
    if notification_needed # not needed for restarts or recover ops
      if task.status == 'Completed'
        Message.send_message(task.user,
                             :message_type  => :notice,
                             :header        => "Task #{task.name} Completed Successfully",
                             :description   => "Oh great!",
                             :variable_text => "[[#{task.bname_tid}][/tasks/show/#{task.id}]]"
                            )
      elsif task.status =~ /^Failed/
        Message.send_message(task.user,
                             :message_type  => :error,
                             :header        => "Task #{task.name} #{task.status}",
                             :description   => "Sorry about that. Check the task's log.",
                             :variable_text => "[[#{task.bname_tid}][/tasks/show/#{task.id}]]"
                            )
      end
    end


  # A CbrainTransitionException can occur just before we try
  # setup_and_submit_job() or post_process(); it's allowed, it means
  # some other worker has beated us to the punch. So we just ignore it.
  rescue CbrainTransitionException => te
    worker_log.debug "Transition Exception: task '#{task.bname_tid}' FROM='#{te.from_state}' TO='#{te.to_state}' FOUND='#{te.found_state}'"
    return

  # Any other error is critical and fatal; we're already
  # trapping all exceptions in setup_and_submit_job() and post_process(),
  # so if an exception went through anyway, it's a CODING BUG.
  rescue => e
    worker_log.fatal "Exception processing task #{task.bname_tid}: #{e.class.to_s} #{e.message}\n" + e.backtrace[0..10].join("\n")
    raise e
  end

end
