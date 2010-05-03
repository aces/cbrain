
#
# CBRAIN Project
#
# DRMAA Job Wrapper Class
#
# Original author: Pierre Rioux
#
# $Id$
#

require 'scir'
require 'stringio'
require 'base64'
require 'fileutils'
require 'cbrain_exception'

#Abstract model representing a job running on a cluster. This is the core class for
#launching GridEngine/PBS jobs using Scir.
#
#=Attributes:
#[<b>user_id</b>] The id of the user who requested this task.
#[<b>bourreau_id</b>] The id of the Bourreau on which the task is running.
#[<b>status</b>] The status of the current task.
#[<b>params</b>] A hash of the parameters sent in the job request from BrainPortal.
#[<b>drmaa_jobid</b>] The job id of the running task. This id is a string
#                     specific to the cluster management system configured for the
#                     bourreau, and has no meaning outside of there.
#[<b>drmaa_workdir</b>] The work directory in which the task is running. Like the
#                       *drmaa_jobid*, this directory has no meaning outside
#                       of the context of the host where the Bourreau is running.
#[<b>share_wd_tid</b>] The task id of another task; if set, the current task will
#                      be configured to execute in the same +drmaa_workdir+.
#[<b>prerequisites</b>] A hash table providing information about what other
#                       tasks the current task depend on.
#[<b>log</b>] A log of task's progress.
#
#<b>DrmaaTask should not be instantiated directly.</b> Instead, subclasses of DrmaaTask should be created to
#represent requests for specific processing tasks.
#Unlike the DrmaaTask model on the portal side, these here are *ActiveRecord* models, meaning
#they do represent rows in the database directly.
#
#= Creating a DrmaaTask subclass
#Subclasses of DrmaaTask will have to override the following methods to function properly:
#[<b>setup</b>] Perform any preparatory steps before launching the job (e.g. syncing files).
#[*drmaa_commands*] Returns an array of the bash commands to be run by the job.
#[*save_results*] Perform any finalization steps after the job is run (e.g. saving result files).
#
#Note that all these methods can access request parameters through the hash in the +params+
#attribute.
#
#A generator script has been written to simplify the creation of DrmaaTask subclasses. To
#use it, simply go to the Bourreau application's base directory and run:
#  script/generate cluster_task <your_task_name>
#This will create a template for your task.
#
#Instructions in the files themselves will indicate how to integrate your task into the system.
class DrmaaTask < ActiveRecord::Base

  Revision_info="$Id$"

  # These basenames might get modified with suffixes appended to them.
  QSUB_SCRIPT_BASENAME = ".qsub"      # appended: ".{id}.sh"
  QSUB_STDOUT_BASENAME = ".qsub.out"  # appended: ".{id}"
  QSUB_STDERR_BASENAME = ".qsub.err"  # appended: ".{id}"

  include DrmaaTaskCommon

  # The attribute 'params' is a serialized hash table
  # containing job-specific parameters; it's up to each
  # subclass of DrmaaTask to find/use/define its content
  # as necessary.
  serialize :params

  # The attribute 'prerequisites' is a serialized hash table
  # containing the information about whether the current
  # task depend on the states of other tasks. As an example,
  # if the hash is this:
  #
  #     {
  #        :for_setup           => { "T12" => "Queued", "T13" => "Completed" },
  #        :for_post_processing => { "T66" => "Failed" },
  #     }
  #
  # then the task will be setup by a Worker only when task #12 and #13 are
  # in the indicated states or further, and the task will enter post_process() only
  # when task #66 has failed. The only allowed keys right now are
  # :for_setup and :for_post_processing, as these are the only two
  # states triggered by Workers.
  #
  # The task's ID are serialized with strings with a prefix consisting
  # of the single character 'T'. This is needed so that the structure
  # is properly serialized in XML during ActiveResource transport.
  #
  # The only allowed state values for the conditions are:
  #
  #  - 'Queued' (which also covers ALL subsequent states up to 'Completed')
  #  - 'Data Ready' (which also covers 'Completed')
  #  - 'Completed'
  #  - 'Failed' (which covers all failures)
  #
  # As an aide, note that in a way, a value 'n' in the DrmaaTask attribute
  # :share_wd_tid also implies this prerequisite:
  #
  #     :for_setup => { "T#{n}" => "Queued" }
  #
  # unless a more restrictive prerequisite is already supplied for task 'n'.
  serialize :prerequisites

  def initialize(arguments = {}) #:nodoc:
    super(arguments)
    baserev = Revision_info
    subrev  = self.revision_info
    self.addlog("#{baserev.svn_id_file} revision #{baserev.svn_id_rev}")
    self.addlog("#{subrev.svn_id_file} revision #{subrev.svn_id_rev}")
  end



  ##################################################################
  # Main User API Methods
  # setup(), drmaa_commands() and save_results()
  ##################################################################

  # This needs to be redefined in a subclass.
  # Returning true means that everything went fine
  # during setup. Returning false will mark the
  # job with a final status "Failed To Setup".
  #
  # The method has of course access to all the
  # fields of ActiveRecord, but the only
  # two that are of used are self.params and
  # self.drmaa_workdir (which graciously when is
  # already the current working directory when
  # this method is called).
  def setup
    true
  end

  # This needs to be redefined in a subclass.
  # It should return an array of bash commands,
  # each array element being one line of the bash
  # script.
  #
  # Like setup(), it has access to self.params and
  # self.drmaa_workdir
  def drmaa_commands
    [ "true >/dev/null" ]
  end

  # This needs to be redefined in a subclass.
  # Returning true means that everything went fine
  # during result gathering. Returning false will mark
  # the job with a final status "Failed To PostProcess".
  #
  # Like setup(), it has access to self.params and
  # self.drmaa_workdir.
  def save_results
    true
  end



  ##################################################################
  # Main User API Methods
  # Error recovery and restarts
  ##################################################################

  # This needs to be redefined in a subclass.
  # This method must do what is necessary to figure out
  # why a task was in 'Failed To Setup' and fix things.
  # If it returns true, the task will be sent back to the
  # 'New' state. The run_number will stay the same.
  def recover_from_setup_failure
    false
  end

  # This needs to be redefined in a subclass.
  # This method must do what is necessary to figure out
  # why a task was in 'Failed On Cluser' and fix things.
  # If it returns true, the task will be restarted on
  # the cluster (with a new job ID) and returned to
  # stated 'Queued'. The run_number will stay the same.
  def recover_from_cluster_failure
    false
  end

  # This needs to be redefined in a subclass.
  # This method must do what is necessary to figure out
  # why a task was in 'Failed To PostProcess' and fix things.
  # If it returns true, the task will be sent back to the
  # 'Data Ready' state. The run_number will stay the same.
  def recover_from_post_processing_failure
    false
  end

  # This needs to be redefined in a subclass.
  # This method must prepare the task's work directory
  # such that it can be restarted anew from the 'Setting
  # Up' state. If the method returns false, the task
  # cannot be restarted in this way. Note that the
  # run_number will be increased by one if a restart is
  # attempted.
  def restart_at_setup
    false
  end

  # This needs to be redefined in a subclass.
  # This method must prepare the task's work directory
  # such that it can be restarted anew from the 'Queued'
  # state. If the method returns false, the task
  # cannot be restarted in this way. Note that the
  # run_number will be increased by one if a restart is
  # attempted.
  def restart_at_cluster
    false
  end

  # This needs to be redefined in a subclass.
  # This method must prepare the task's work directory
  # such that it can be restarted anew from the 'Post'
  # Processing' state. If the method returns false, the task
  # cannot be restarted in this way. Note that the
  # run_number will be increased by one if a restart is
  # attempted.
  def restart_at_post_processing
    false
  end



  ##################################################################
  # Main control methods (mainly called by the BourreauWorker)
  ##################################################################

  # This is called only by a BourreauWorker once when the object is new.
  # A temporary, grid-aware working directory is created
  # for the job, and the task-specific setup() method is invoked in it.
  # Then the task's BASH commands are submitted to the cluster.
  def setup_and_submit_job

    cb_error "Expected Task object to be in 'Setting Up' state." unless
      self.status == 'Setting Up'

    # This used to be run in background, but now that
    # we have a worker subprocess, we no longer need
    # to have a spawn occur here.
    begin
      self.addlog("Setting Up.")
      self.makeDRMAAworkdir
      Dir.chdir(self.drmaa_workdir) do
        if ! self.setup  # as defined by subclass
          self.addlog("Failed to setup: 'false' returned by setup().")
          self.status = "Failed To Setup"
        elsif ! self.submit_cluster_job
          self.addlog("Failed to start: 'false' returned by submit_cluster_job().")
          self.status = "Failed To Setup"
        else
          self.addlog("Setup and submit process successful.")
          # the status is moving forward at its own pace now
        end
      end
    rescue => e
      self.addlog_exception(e,"Exception raised while setting up:")
      self.status = "Failed To Setup"
    end

    self.save
  end

  # This is called by a Worker to finish processing a job that has
  # successfully run on the cluster. The main purpose
  # is to call the subclass' supplied save_result() method
  # then cleanup the temporary grid-aware directory.
  def post_process

    cb_error "Expected Task object to be in 'Post Processing' state." unless
      self.status == 'Post Processing'

    # This used to be run in background, but now that
    # we have a worker subprocess, we no longer need
    # to have a spawn occur here.
    begin
      self.addlog("Starting asynchronous postprocessing.")
      saveok = false
      Dir.chdir(self.drmaa_workdir) do
        # Call the subclass-provided save_results()
        saveok = self.save_results
      end
      if ! saveok
        self.status = "Failed On Cluster"
        self.addlog("Data processing failed on the cluster.")
      else
        self.addlog("Asynchronous postprocessing completed.")
        self.status = "Completed"
      end
    rescue Exception => e
      self.addlog_exception(e,"Exception raised while post processing results:")
      self.status = "Failed To PostProcess"
    end

    self.save
  end

  # Possible returned status values:
  # [<b>New</b>] The task is new and not yet set up.
  # [<b>Setting Up</b>] The task is in its asynchronous 'setup' state.
  # [<b>Failed *</b>]  (To Setup, On Cluster, etc) The task failed at some stage.
  # [<b>Queued</b>] The task is queued.
  # [<b>On CPU</b>] The task is underway.
  # [<b>Data Ready</b>] The task has been completed, but data has not been sent back to BrainPortal.
  # [<b>Post Processing</b>] The task is sending back its data to the BrainPortal.
  # [<b>Completed</b>] The task has been completed, and data has been sent back to BrainPortal.
  # [<b>On Hold</b>] The task is queued, but should not be sent to the CPU even if it's ready.
  # [<b>Suspended</b>] The has been suspended while it was on CPU.
  # [<b>Terminated</b>] The task has been terminated by request of the user.
  #
  # The values are determined by BOTH the current state returned by
  # the cluster and the previously recorded value of status().
  # Some other values are reached by calling methods, such as
  # post_process() which changes <b>Data Ready</b> to <b>Completed</b>.
  def update_status

    ar_status = self.status
    if ar_status.blank?
      cb_error "Unknown blank status obtained from DrmaaTask ActiveRecord #{self.id}."
    end

    # Final states that we can't get out of, except for:
    # - "Data Ready" which can be moved to "Post Processing"
    #    through the method call save_results()
    # - "Post Processing" which will be moved to "Completed"
    #    through the method call save_results()
    return ar_status if ar_status.match(/^(New|Setting Up|Failed.*|Data Ready|Terminated|Completed|Post Processing|Recover|Restart)$/)

    # This is the expensive call, the one that queries the cluster.
    drmaastatus = self.drmaa_status
    #self.addlog("ar_status is #{ar_status} ; drmaa stat is #{drmaastatus}")

    # Steady states for cluster jobs
    if drmaastatus.match(/^(On CPU|Suspended|On Hold|Queued)$/)
      self.status_transition(self.status,drmaastatus) # try to update; ignore errors.
      return self.status
    end

    # At this point here then, drmaastatus == "Does Not Exist"
    if ar_status.match(/^(On CPU|Suspended|On Hold|Queued)$/)
      self.status_transition(self.status,"Data Ready") # try to update; ignore errors.
      return self.status
    end

    cb_error "DRMAA job finished with unknown Active Record status #{ar_status} and DRMAA status #{drmaastatus}"
  end

  # This method changes the status attribute
  # in the current task object to +to_state+ but
  # also makes sure the current value is +from_state+ .
  # The change is performed in a transaction where
  # the record is locked, to ensure the transition is
  # not trashed by another process. The method returns
  # true if the transition was successful, and false
  # if anything went wrong.
  def status_transition(from_state, to_state)
    DrmaaTask.transaction do
      self.lock!
      return false if self.status != from_state
      return true  if from_state == to_state # NOOP
      self.status = to_state
      self.save!
    end
    true
  end

  # This method acts like status_transition(),
  # but it raises a CbrainTransitionException
  # on failures.
  def status_transition!(from_state, to_state)
    unless status_transition(from_state,to_state)
      ohno = CbrainTransitionException.new(
        "Task status was changed before lock was acquired for task '#{self.id}'.\n" +
        "Expected: '#{from_state}' found: '#{self.status}'."
      )
      ohno.original_object  = self
      ohno.from_state       = from_state
      ohno.to_state         = to_state
      ohno.found_state      = self.status
      raise ohno
    end
    true
  end



  ##################################################################
  # Task Control Methods
  # (hold, suspend, terminate, etc etc)
  ##################################################################

  #Terminate the task (if it's currently in an appropriate state.)
  def terminate
    return unless self.status.match(/^(On CPU|On Hold|Suspended|Queued)$/)
    begin
      Scir::Session.session_cache.terminate(self.drmaa_jobid)
      self.status = "Terminated"
    rescue
      # nothing to do
    end
  end

  #Suspend the task (if it's currently in an appropriate state.)
  def suspend
    return unless self.status == "On CPU"
    begin
      Scir::Session.session_cache.suspend(self.drmaa_jobid)
      self.status = "Suspended"
    rescue
      # nothing to do
    end
  end

  #Resume processing the task if it was suspended.
  def resume
    begin
      return unless self.status == "Suspended"
      Scir::Session.session_cache.resume(self.drmaa_jobid)
      self.status = "On CPU"
    rescue
      # nothing to do
    end
  end

  #Put the task on hold if it is currently queued.
  def hold
    return unless self.status == "Queued"
    begin
      Scir::Session.session_cache.hold(self.drmaa_jobid)
      self.status = "On Hold"
    rescue
      # nothing to do
    end
  end

  #Release the task from a suspended state.
  def release
    begin
      return unless self.status == "Suspended"
      Scir::Session.session_cache.release(self.drmaa_jobid)
      self.status = "Queued"
    rescue
      # nothing to do
    end
  end



  ##################################################################
  # Methods For Recovering From Failed Tasks
  # Methods For Restarting Completed Tasks
  ##################################################################

  # This triggers the recovery mechanism for all Failed tasks.
  # This simply sets a special value in the 'status' field
  # that will be handled by the Bourreau Worker.
  def recover
    curstat = self.status
    if curstat =~ /^Failed (Setup|PostProcess) Prerequisites$/
      failed_where = Regexp.last_match[1]
      self.addlog("Resetting prerequisites checking for '#{failed_where}'.")
      self.status = "New"        if failed_where == "Setup"
      self.status = "Data Ready" if failed_where == "PostProcess"
      return
    end
    begin
      return unless curstat =~ /^Failed (To Setup|On Cluster|To PostProcess)$/
      failedwhen = Regexp.last_match[1]
      self.addlog("Scheduling recovery from '#{curstat}'.")
      self.status = "Recover Setup"       if failedwhen == "To Setup"
      self.status = "Recover Cluster"     if failedwhen == "On Cluster"
      self.status = "Recover PostProcess" if failedwhen == "To PostProcess"
    rescue
      # nothing to do
    end
  end

  # This triggers the restart mechanism for all Completed tasks.
  # This simply sets a special value in the 'status' field
  # that will be handled by the Bourreau Worker.
  def restart(atwhat)
    begin
      return unless self.status == 'Completed'
      return unless atwhat =~ /^(Setup|Cluster|PostProcess)$/
      self.addlog("Scheduling restart at '#{atwhat}'.")
      self.status="Restart #{atwhat}" # will be handled by worker
    rescue
      # nothing to do
    end
  end



  ##################################################################
  # Prerequisites Fulfillment Evaluation Methods
  ##################################################################

  # Returns a keyword indicating how the task's prerequisites
  # are satisfied; the argument +for_state+ indicates which of two
  # possible future transitions to check for: :for_setup or
  # :for_post_processing. This method is mostly used by the
  # BourreauWorker code, for deciding whether or not the time
  # as come to send the task to the cluster or to post process it.
  # The method returns three possible keywords:
  #
  # [[:go]] All prerequisites are satisfied.
  # [[:wait]] Some prerequisites are not yet satisfied.
  # [[:fail]] Some prerequisites have failed and thus at
  #           this point the task can never proceed.
  def prerequisites_fulfilled?(for_state)
    allprereqs = self.prerequisites    || {}
    prereqs    = allprereqs[for_state] || {}
    return :go if prereqs.empty?
    final_action = :go
    prereqs.keys.each do |t_taskid|  # taskid is a string like "T62"
      cb_error "Invalid prereq key '#{t_taskid}'." unless t_taskid =~ /^T(\d+)$/
      task_id = Regexp.last_match[1].to_i
      cb_notice "Task depends on itself!" if task_id == self.id # Cannot depend on yourself!!!
      task = DrmaaTask.find(task_id) rescue nil
      cb_error "Could not find task '#{task_id}'" unless task
      needed_state   = prereqs[t_taskid] # one of "Queued" "Data Ready" "Completed" or "Fail"
      covered_states = PREREQS_STATES_COVERED_BY[needed_state]
      cb_error "Could not found coverage list for '#{needed_state}'" unless covered_states
      action = covered_states[task.status] || :fail
      cb_notice "Task '#{task.bname_tid}' is in state '#{task.status}' " +
                "while we wanted it in '#{needed_state}'." if action == :fail
      cb_error "Unknown action entry '#{action}' in prereq table? " +
               "Needed=#{needed_state} Task=#{task.bname_tid} in '#{task.status}'." unless action == :go || action == :wait
      final_action = :wait if action == :wait
      # we still need to check the rest of the tasks for :fail, so we loop back here.
    end
    return final_action # one of :go if ALL are :go, :wait if there is at least one :wait
  rescue CbrainNotice => e
    self.addlog("Prerequisite Check Failure: #{e.message}")
    self.save
    return :fail
  rescue CbrainError => e
    self.addlog("Prerequisite Check CBRAIN Error: #{e.message}")
    self.save
    return :fail
  rescue => e
    self.addlog_exception(e,"Prerequisite Check Exception:")
    self.save
    return :fail
  end

  # This method adjusts the prerequisites
  # of the task if a another task ID's was supplied in :share_wd_tid
  # and no prerequisites have been specified for that other task.
  def adjust_prereqs_for_shared_tasks_wd
    otask_id = self.share_wd_tid          # task ID of other task
    return if otask_id.blank?             # nothing to do if there is no other task ID
    prereqs  = self.prerequisites || {}   # The prereq structure
    self.prerequisites = prereqs          # Make sure it's saved in the object
    forsetup = prereqs[:for_setup] ||= {} # Make sure the :for_setup exists
    t_otid   = "T#{otask_id}"             # Task IDs in prereqs are "Tnn"
    forsetup[t_otid] ||= "Queued"         # If there is no prereq, create one.
    true
  end



  ##################################################################
  # Internal Logging Methods
  ##################################################################

  #Record a +message+ in this task's log.
  def addlog(message, options = {})
    log = self.log
    log = "" if log.nil? || log.empty?
    callerlevel    = options[:caller_level] || 0
    calling_info   = caller[callerlevel]
    calling_method = options[:prefix] || ( calling_info.match(/in `(.*)'/) ? ($1 + "() ") : "unknown() " )
    calling_method = "" if options[:no_caller]
    lines = message.split(/\s*\n/)
    lines.pop while lines.size > 0 && lines[-1] == ""
    message = lines.join("\n") + "\n"
    log +=
      Time.now.strftime("[%Y-%m-%d %H:%M:%S] ") + calling_method + message
    self.log = log
  end

  # Compatibility method to let this class
  # act a bit like the other classes extended
  # by the ActRecLog module (see logging.rb).
  # This is necessary because DrmaaTask objects
  # have their very own internal embedded log
  # and do NOT use the methods defined by the
  # ActRecLog module.
  def getlog
    self.log
  end

  # Compatibility method to let this class
  # act a bit like the other classes extended
  # by the ActRecLog module (see logging.rb).
  # This is necessary because DrmaaTask objects
  # have their very own internal embedded log
  # and do NOT use the methods defined by the
  # ActRecLog module.
  def addlog_context(context,message="") #:nodoc:
    prev_level     = caller[0]
    calling_method = prev_level.match(/in `(.*)'/) ? ($1 + "()") : "unknown()"

    class_name     = context.class.to_s
    class_name     = context.to_s if class_name == "Class"
    rev_info       = context.revision_info
    pretty_info    = rev_info.svn_id_pretty_rev_author_date

    full_message   = "#{class_name} #{calling_method} revision #{pretty_info}"
    full_message   += " #{message}" unless message.blank?
    self.addlog(full_message, :no_caller => true )
  end

  # Compatibility method to let this class
  # act a bit like the other classes extended
  # by the ActRecLog module (see logging.rb).
  # This is necessary because DrmaaTask objects
  # have their very own internal embedded log
  # and do NOT use the methods defined by the
  # ActRecLog module.
  def addlog_revinfo(anobject,message="") #:nodoc:
    class_name     = anobject.class.to_s
    class_name     = anobject.to_s if class_name == "Class"
    rev_info       = anobject.revision_info
    pretty_info    = rev_info.svn_id_pretty_rev_author_date

    full_message   = "#{class_name} revision #{pretty_info}"
    full_message   += " #{message}" unless message.blank?
    self.addlog(full_message, :no_caller => true )
  end

  # Records in the task's log the info about an exception.
  # This happens frequently not only in this code here
  # but also in subclasses, in the Bourreau controller and in
  # the BourreauWorkers, so it's worth having this utility.
  # The method can also be called by DrmaaTask programmers.
  def addlog_exception(exception,message="Exception raised:",backtrace_lines=15) #:nodoc:
    message = "Exception raised:" if message.blank?
    message.sub!(/[\s:]*$/,":")
    self.addlog("#{message} #{exception.class}: #{exception.message}")
    if backtrace_lines > 0
      backtrace_lines = exception.backtrace.size - 1 if backtrace_lines >= exception.backtrace.size
      exception.backtrace[1..backtrace_lines].each { |m| self.addlog(m) }
    end
  end



  ##################################################################
  # ActiveRecord Lifecycle methods
  ##################################################################

  # All object destruction also implies termination!
  def before_destroy #:nodoc:
    self.terminate
    self.removeDRMAAworkdir
  end



  ##################################################################
  # XML Serialization Methods
  ##################################################################

  # It is VERY important to add a pseudo-attribute 'type'
  # to the XML records created for the Drmaa* objects, as
  # this is used on the other end of an ActiveResource
  # connection to properly re-instanciate the object
  # with the proper type (see the patch to instantiate_record()
  # in the ActiveResource model for DrmaaTask on BrainPortal)
  def to_xml(options = {}) #:nodoc:
    options[:methods] ||= []
    options[:methods] << :type            unless options[:methods].include?(:type)
    options[:methods] << :capt_stdout_b64 unless options[:methods].include?(:capt_stdout_b64)
    options[:methods] << :capt_stderr_b64 unless options[:methods].include?(:capt_stderr_b64)
    super options
  end

  # This is needed by the ActiveResource controller on
  # Bourreau to figure out which key of the update()
  # request contains the updated attributes (the key
  # vary with the class name, so DrmaaAbc is stored in
  # drmaa_abc)
  def uncamelize #:nodoc:
    self.class.to_s.downcase.sub(/^drmaa_?/i,"drmaa_")
  end

  # Read back the STDOUT and STDERR files for the job, and
  # store (part of) their contents in the task's object;
  # this is called explicitely only in the case when the
  # portal performs a 'show' request on a single task
  # otherise it's too expensive to do it every time. The
  # pseudo attributes @capt_stdout_b64 and @capt_stderr_b64
  # are not really part of the DrmaaTask model.
  def capture_job_out_err
     return if self.new_record?
     stdoutfile = self.stdoutDRMAAfilename
     stderrfile = self.stderrDRMAAfilename
     #@capt_stdout_b64 = Base64.encode64(File.read(stdoutfile)) if File.exist?(stdoutfile)
     #@capt_stderr_b64 = Base64.encode64(File.read(stderrfile)) if File.exist?(stderrfile)
     if stdoutfile && File.exist?(stdoutfile)
        #io = IO.popen("tail -30 #{stdoutfile} | fold -b -w 200 | tail -100","r")
        io = IO.popen("tail -100 #{stdoutfile}","r")
        @capt_stdout_b64 = Base64.encode64(io.read)
        io.close
     end
     if stderrfile && File.exist?(stderrfile)
        #io = IO.popen("tail -30 #{stderrfile} | fold -b -w 200 | tail -100","r")
        io = IO.popen("tail -100 #{stderrfile}","r")
        @capt_stderr_b64 = Base64.encode64(io.read)
        io.close
     end
  end



  ##################################################################
  # Cluster Task Status Update Methods
  ##################################################################

  protected

  # The list of possible DRMAA states is larger than
  # the ones we need for CBRAIN, so here is a mapping
  # to our shorter list. Note that when a job finishes
  # on the cluster, we cannot tell whether it was all
  # correctly done or not, so we only have "Does Not Exist"
  # as a state. It's up to the subclass' save_results()
  # to figure out if the processing was successfull or
  # not.
  @@DRMAA_States_To_Status ||= {
                               # The textual strings are important
                               # ---------------------------------
    Scir::STATE_UNDETERMINED          => "Does Not Exist",
    Scir::STATE_QUEUED_ACTIVE         => "Queued",
    Scir::STATE_SYSTEM_ON_HOLD        => "On Hold",
    Scir::STATE_USER_ON_HOLD          => "On Hold",
    Scir::STATE_USER_SYSTEM_ON_HOLD   => "On Hold",
    Scir::STATE_RUNNING               => "On CPU",
    Scir::STATE_SYSTEM_SUSPENDED      => "Suspended",
    Scir::STATE_USER_SUSPENDED        => "Suspended",
    Scir::STATE_USER_SYSTEM_SUSPENDED => "Suspended",
    Scir::STATE_DONE                  => "Does Not Exist",
    Scir::STATE_FAILED                => "Does Not Exist"
  }

  # Returns <b>On CPU</b>, <b>Queued</b>, <b>On Hold</b>, <b>Suspended</b> or
  # <b>Does Not Exist</b>.
  # This set of states is *NOT* exactly the same as for status()
  # as a non-existing DRMAA job might mean a job not started,
  # a killed job or a job that's exited properly, and we can't determine
  # which of the three from the DRMAA::Session#job_ps()
  def drmaa_status
    state = Scir::Session.session_cache.job_ps(self.drmaa_jobid)
    status = @@DRMAA_States_To_Status[state] || "Does Not Exist"
    return status
  end



  ##################################################################
  # Cluster Task Creation Methods
  ##################################################################

  # Submit the actual job request to the cluster management software.
  # Expects that the WD has already been changed.
  def submit_cluster_job
    self.addlog("Launching DRMAA job.")

    name     = self.name
    commands = self.drmaa_commands  # Supplied by subclass; can use self.params
    workdir  = self.drmaa_workdir

    # Special case of RUBY-only jobs (jobs that have no cluster-side).
    # In this case, only the 'Setting Up' and 'Post Processing' states
    # are actually performed.
    if commands.nil? || commands.size == 0
      self.addlog("No BASH commands associated with this task. Jumping to state 'Post Processing'.")
      self.status = "Data Ready"  # Will trigger Post Processing later on.
      self.save
      return true
    end

    # Create a bash command script out of the text
    # lines supplied by the subclass
    qsubfile = QSUB_SCRIPT_BASENAME + ".#{self.run_id}.sh"
    File.open(qsubfile,"w") do |io|
      io.write(
        "#!/bin/sh\n" +
        "\n" +
        "# Script created automatically by #{self.class.to_s}\n" +
        "# #{Revision_info}\n" +
        "\n" +
        "# Global Bourreau initialization section\n" +
        CBRAIN::EXTRA_BASH_INIT_CMDS.join("\n") + "\n" +
        "\n" +
        "# User commands section\n" +
        commands.join("\n") +
        "\n"
      )
    end

    # Create the DRMAA job object
    Scir::Session.session_cache   # Make sure it's loaded.
    job = Scir::JobTemplate.new_jobtemplate
    job.command = "/bin/bash"
    job.arg     = [ qsubfile ]
    job.stdout  = ":" + self.stdoutDRMAAfilename
    job.stderr  = ":" + self.stderrDRMAAfilename
    job.join    = false
    job.wd      = workdir
    job.name    = name

    # Log version of DRMAA lib, e.g.
    # Using Scir for 'PBS/Torque' version '1.0' implementation 'PBS DRMAA v. 1.0 <http://sourceforge.net/projects/pbspro-drmaa/>'
    drm     = Scir.drm_system
    version = Scir.version
    impl    = Scir.drmaa_implementation
    self.addlog("Using Scir for '#{drm}' version '#{version}' implementation '#{impl}'.")

    impl_revinfo = Scir::Session.session_cache.revision_info
    impl_file    = impl_revinfo.svn_id_file
    impl_rev     = impl_revinfo.svn_id_rev
    impl_author  = impl_revinfo.svn_id_author
    impl_date    = impl_revinfo.svn_id_date
    impl_time    = impl_revinfo.svn_id_time
    self.addlog("Implementation in file '#{impl_file}' revision '#{impl_rev}' from '#{impl_date + " " + impl_time}'.")

    # Queue the job and return true, at this point
    # it's not our 'job' to figure out if it worked
    # or not.
    jobid            = Scir::Session.session_cache.run(job)
    self.drmaa_jobid = jobid
    self.status      = "Queued"
    self.addlog("Queued as job ID '#{jobid}'.")
    return true

  end



  ##################################################################
  # Cluster Job Shared Work Directory Methods
  ##################################################################

  # Create the directory in which to run the job.
  # If the task contains the ID of another task in
  # the attribute :share_wd_tid, then that other
  # task's work directory will be used instead.
  def makeDRMAAworkdir
    # Use the work directory of another task
    otask_id = self.share_wd_tid
    if ! otask_id.blank?
      otask = DrmaaTask.find(otask_id)
      cb_error "Cannot use the work directory of a task that belong to another Bourreau." if otask.bourreau_id != self.bourreau_id
      owd   = otask.drmaa_workdir
      cb_error "Cannot find the work directory of other task '#{otask_id}'."      if owd.blank?
      cb_error "The work directory '#{owd} of task '#{otask_id}' does not exist." unless File.directory?(owd)
      self.drmaa_workdir = owd
      self.addlog("Using workdir '#{owd}' of task '#{otask.bname_tid}'.")
      return
    end

    # Create our own work directory
    name = self.name
    user = self.user.login
    self.drmaa_workdir = (CBRAIN::DRMAA_sharedir + "/" + "#{user}-#{name}-P" + Process.pid.to_s + "-I" + self.id.to_s)
    self.addlog("Trying to create workdir '#{self.drmaa_workdir}'.")
    Dir.mkdir(self.drmaa_workdir,0700) unless File.directory?(self.drmaa_workdir)
  end

  # Remove the directory created to run the job.
  def removeDRMAAworkdir
    unless self.drmaa_workdir.blank?
      self.addlog("Removing workdir '#{self.drmaa_workdir}'.")
      FileUtils.remove_dir(self.drmaa_workdir, true)
      #system("/bin/rm -rf \"#{self.drmaa_workdir}\" >/dev/null 2>/dev/null")
      self.drmaa_workdir = nil
    end
  end



  ##################################################################
  # Cluster Job's STDOUT And STDERR Files Methods
  ##################################################################

  # Returns the filename for the job's captured STDOUT
  # Returns nil if the work directory has not yet been
  # created, or no longer exists. The file itself is not
  # garanteed to exist, either.
  def stdoutDRMAAfilename
    workdir = self.drmaa_workdir
    return nil unless workdir
    if File.exists?("#{workdir}/.qsub.sh.out") # for compatibility will old tasks
      "#{workdir}/.qsub.sh.out"                # for compatibility will old tasks
    else
      "#{workdir}/#{QSUB_STDOUT_BASENAME}.#{self.run_id}" # New official convention
    end
  end

  # Returns the filename for the job's captured STDERR
  # Returns nil if the work directory has not yet been
  # created, or no longer exists. The file itself is not
  # garanteed to exist, either.
  def stderrDRMAAfilename
    workdir = self.drmaa_workdir
    return nil unless workdir
    if File.exists?("#{workdir}/.qsub.sh.err") # for compatibility will old tasks
      "#{workdir}/.qsub.sh.err"                # for compatibility will old tasks
    else
      "#{workdir}/#{QSUB_STDERR_BASENAME}.#{self.run_id}" # New official convention
    end
  end

  # Returns the captured STDOUT for the
  # task; this pseudo-attribute is only
  # filled in after explicitely calling
  # the method capture_job_out_err()
  def capt_stdout_b64
    @capt_stdout_b64
  end

  # Returns the captured STDERR for the
  # task; this pseudo-attribute is only
  # filled in after explicitely calling
  # the method capture_job_out_err()
  def capt_stderr_b64
    @capt_stderr_b64
  end

end
