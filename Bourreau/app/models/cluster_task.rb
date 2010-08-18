
#
# CBRAIN Project
#
# Bourreau CbrainTask Wrapper Class
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
#launching GridEngine/PBS/MOAB/UNIX jobs (etc) using Scir.
#
#See the document CbrainTask.txt for a complete introduction.
#
#=Attributes:
#[<b>user_id</b>] The id of the user who requested this task.
#[<b>bourreau_id</b>] The id of the Bourreau on which the task is running.
#[<b>status</b>] The status of the current task.
#[<b>params</b>] A hash of the parameters sent in the job request from BrainPortal.
#[<b>cluster_jobid</b>] The job id of the running task. This id is a string
#                       specific to the cluster management system configured for the
#                       bourreau, and has no meaning outside of there.
#[<b>cluster_workdir</b>] The work directory in which the task is running. Like the
#                         *cluster_jobid*, this directory has no meaning outside
#                         of the context of the host where the Bourreau is running.
#[<b>share_wd_tid</b>] The task id of another task; if set, the current task will
#                      be configured to execute in the same +cluster_workdir+.
#[<b>prerequisites</b>] A hash table providing information about what other
#                       tasks the current task depend on.
#[<b>log</b>] A log of task's progress.
#
#<b>ClusterTask objects should not be instantiated directly.</b> Instead, subclasses of ClusterTask should be created to
#represent requests for specific processing tasks.
#
#= Creating a ClusterTask subclass
#Subclasses of ClusterTask will have to override the following methods to function properly:
#[<b>setup</b>] Perform any preparatory steps before launching the job (e.g. syncing files).
#[*cluster_commands*] Returns an array of the bash commands to be run by the job.
#[*save_results*] Perform any finalization steps after the job is run (e.g. saving result files).
#
#Note that all these methods can access request parameters through the hash in the +params+
#attribute.
#
#A generator script has been written to simplify the creation of ClusterTask subclasses. To
#use it, simply go to the Bourreau application's base directory and run:
#  script/generate cluster_task <your_task_name>
#This will create a template for your task.
#
#Instructions in the files themselves will indicate how to integrate your task into the system.
class ClusterTask < CbrainTask

  Revision_info="$Id$"

  # These basenames might get modified with suffixes appended to them.
  QSUB_SCRIPT_BASENAME = ".qsub"      # appended: ".{id}.sh"
  QSUB_STDOUT_BASENAME = ".qsub.out"  # appended: ".{id}"
  QSUB_STDERR_BASENAME = ".qsub.err"  # appended: ".{id}"



  ##################################################################
  # Core Object Methods
  ##################################################################

  # Automatically register the task's version when new() is invoked.
  def initialize(arguments = {}) #:nodoc:
    super(arguments)
    baserev = Revision_info
    subrev  = self.revision_info
    self.addlog("#{baserev.svn_id_file} revision #{baserev.svn_id_rev}")
    self.addlog("#{subrev.svn_id_file} revision #{subrev.svn_id_rev}")
  end



  ##################################################################
  # Main User API Methods
  # setup(), cluster_commands() and save_results()
  ##################################################################

  # This needs to be redefined in a subclass.
  # Returning true means that everything went fine
  # during setup. Returning false or raising an
  # exception will mark the job with a final
  # status "Failed To Setup".
  def setup
    true
  end

  # This needs to be redefined in a subclass.
  # It should return an array of bash commands,
  # each array element being one line of the bash
  # script.
  def cluster_commands
    [ "true >/dev/null" ]
  end

  # This needs to be redefined in a subclass.
  # Returning true means that everything went fine
  # during result gathering. Returning false will mark
  # the job with a final status "Failed On Cluster".
  # Raising an exception will mark the job with
  # a final status "Failed To PostProcess".
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
  #
  # Note that including the module RecoverableTask
  # will provide a copy of this method that simply
  # returns true; this is useful if your setup()
  # method is naturally recoverable.
  def recover_from_setup_failure
    false
  end

  # This needs to be redefined in a subclass.
  # This method must do what is necessary to figure out
  # why a task was in 'Failed On Cluser' and fix things.
  # If it returns true, the task will be restarted on
  # the cluster (with a new job ID) and returned to
  # stated 'Queued'. The run_number will stay the same.
  #
  # Note that including the module RecoverableTask
  # will provide a copy of this method that simply
  # returns true; this is useful if your bash commands
  # returned by cluster_commands() are naturally recoverable.
  def recover_from_cluster_failure
    false
  end

  # This needs to be redefined in a subclass.
  # This method must do what is necessary to figure out
  # why a task was in 'Failed To PostProcess' and fix things.
  # If it returns true, the task will be sent back to the
  # 'Data Ready' state. The run_number will stay the same.
  #
  # Note that including the module RecoverableTask
  # will provide a copy of this method that simply
  # returns true; this is useful if your save_results()
  # method is naturally recoverable.
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
  #
  # Note that including the module RestartableTask
  # will provide a copy of this method that simply
  # returns true; this is useful if your setup()
  # method is naturally restartable.
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
  #
  # Note that including the module RestartableTask
  # will provide a copy of this method that simply
  # returns true; this is useful if your bash commands
  # returned by cluster_commands() are naturally restartable.
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
  #
  # Note that including the module RestartableTask
  # will provide a copy of this method that simply
  # returns true; this is useful if your save_results()
  # method is naturally restartable.
  def restart_at_post_processing
    false
  end



  ##################################################################
  # Utility Methods For CbrainTask:ClusterTask Developers
  ##################################################################

  # Utility method for developers to use while writing
  # a task's setup() or save_results() methods.
  # This method creates a subdirectory in your work directory.
  # To make it partical when writing restartable or recoverable
  # code, it will not complain of the directory already exists,
  # unlike Dir.mkdir() which raises an exception.
  # The +relpath+ MUST be relative and the current directory MUST
  # be the task's work directory.
  def safe_mkdir(relpath,mode=0700)
    cb_error "Current directory is not the task's work directory?" unless self.we_are_in_workdir
    cb_error "New directory argument must be a relative path." if
      relpath.blank? || relpath =~ /^\//
    Dir.mkdir(relpath,mode) unless File.directory?(relpath)
  end

  # Utility method for developers to use while writing
  # a task's setup() or save_results() methods.
  # This method creates a symbolic link in your work directory.
  # To make it partical when writing restartable or recoverable
  # code, it will silently replace a symbolic link that already
  # exists instead of raising an exception like File.symlink().
  # The +relpath+ MUST be relative and the current directory MUST
  # be the task's work directory. The +original_entry+ can be any
  # string, whether it matches an existing path or not.
  def safe_symlink(original_entry,relpath)
    cb_error "Current directory is not the task's work directory?" unless self.we_are_in_workdir
    cb_error "New directory argument must be a relative path." if
      relpath.blank? || relpath =~ /^\//
    File.unlink(relpath) if File.symlink?(relpath)
    File.symlink(original_entry,relpath)
  end

  # Utility method for developers to use while writing
  # a task's setup() or save_results() methods.
  # This method acts like the new() method of Userfile,
  # but if the attribute list match a file already
  # existing then it will return that file instead
  # if a new() entry. This is useful when writing
  # recoverable or restartable code that creates a
  # report or a result file, for instance.
  # +klass+ must be a class that is a subclass of
  # Userfile, and +attlist+ must be an attribute list
  # containing at the minimum :name, :data_provider_id,
  # :user_id and :group_id.
  def safe_userfile_find_or_new(klass,attlist)
    cb_error "Class for file must be a subclass of Userfile." unless
      klass < Userfile
    cb_error "Attribute list missing a required attribute." unless
      [ :name, :data_provider_id, :user_id].all? { |i| attlist.has_key?(i) }
    unless attlist.has_key?(:group_id)
      cb_error "Cannot assign group to file." unless self.group_id
      attlist[:group_id] = self.group_id
    end
    results = klass.find(:all, :conditions => attlist)
    if results.size == 1
      existing_userfile = results[0]
      existing_userfile.cache_is_newer # we assume we want to update the content, always
      return existing_userfile
    end
    cb_error "Found more than one file that match attribute list: '#{attlist.inspect}'." if results.size > 1
    return klass.new(attlist)
  end

  def we_are_in_workdir #:nodoc:
    return false if self.cluster_workdir.blank?
    cur_dir = Dir.getwd
    Dir.chdir(self.cluster_workdir) do  # We need to do this in case the workdir goes through symlinks...
      return false if cur_dir != Dir.getwd
    end
    true
  end

  # This method takes an array of +userfiles+ (or a single one)
  # and add a log entry to each userfile identifying that
  # it was processed by the current task. An optional
  # comment can be appended to the message.
  def addlog_to_userfiles_processed(userfiles,comment = "")
    userfiles = [ userfiles ] unless userfiles.is_a?(Array)
    myname   = self.bname_tid
    mylink   = "/tasks/show/#{self.id}"  # can't use show_task_path() on Bourreau side
    mymarkup = "[[#{myname}][#{mylink}]]"
    userfiles.each do |u|
      next unless u.is_a?(Userfile) && u.id
      u.addlog_context(self,"Processed by task #{mymarkup} #{comment}",3)
    end
  end

  # This method takes an array of +userfiles+ (or a single one)
  # and add a log entry to each userfile identifying that
  # it was created by the current task. An optional
  # comment can be appended to the message.
  def addlog_to_userfiles_created(userfiles,comment = "")
    userfiles = [ userfiles ] unless userfiles.is_a?(Array)
    myname   = self.bname_tid
    mylink   = "/tasks/show/#{self.id}" # can't use show_task_path() on Bourreau side
    mymarkup = "[[#{myname}][#{mylink}]]"
    userfiles.each do |u|
      next unless u.is_a?(Userfile) && u.id
      u.addlog_context(self,"Created/updated by #{mymarkup} #{comment}",3)
    end
  end

  # This method takes an array of userfiles +creatorlist+ (or a single one),
  # another array of userfiles +createdlist+ (or a single one)
  # and records for each created file what were the creators, and for
  # each creator file what files were created, along with a link
  # to the task itself. An optional comment can be appended to all the messages.
  def addlog_to_userfiles_these_created_these(creatorlist, createdlist, comment = "")
    creatorlist = [ creatorlist ] unless creatorlist.is_a?(Array)
    createdlist = [ createdlist ] unless createdlist.is_a?(Array)
    myname   = self.bname_tid
    mylink   = "/tasks/show/#{self.id}"  # can't use show_task_path() on Bourreau side
    mymarkup = "[[#{myname}][#{mylink}]]"
    creatorlist.each do |creator|
      next unless creator.is_a?(Userfile) && creator.id
      creatormarkup = "[[#{creator.name}][/userfiles/#{creator.id}/edit]]" # can't use edit_userfile_path() on Bourreau side
      createdlist.each do |created|
        next unless created.is_a?(Userfile) && created.id
        createdmarkup = "[[#{created.name}][/userfiles/#{created.id}/edit]]" # can't use edit_userfile_path() on Bourreau side
        creator.addlog_context(self,"Used by task #{mymarkup} to create #{createdmarkup} #{comment}",5)
        created.addlog_context(self,"Created by task #{mymarkup} from #{creatormarkup} #{comment}",5)
      end
    end
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

    begin
      self.addlog("Setting Up.")
      self.make_cluster_workdir
      Dir.chdir(self.cluster_workdir) do
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
      Dir.chdir(self.cluster_workdir) do
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
      cb_error "Unknown blank status obtained from CbrainTask ActiveRecord #{self.id}."
    end

    # Final states that we can't get out of, except for:
    # - "Data Ready" which can be moved to "Post Processing"
    #    through the method call save_results()
    # - "Post Processing" which will be moved to "Completed"
    #    through the method call save_results()
    return ar_status if ar_status.match(/^(New|Setting Up|Failed.*|Data Ready|Terminated|Completed|Post Processing|Recover|Restart|Preset)$/)

    # This is the expensive call, the one that queries the cluster.
    clusterstatus = self.cluster_status
    #self.addlog("ar_status is #{ar_status} ; cluster stat is #{clusterstatus}")

    # Steady states for cluster jobs
    if clusterstatus.match(/^(On CPU|Suspended|On Hold|Queued)$/)
      self.status_transition(self.status,clusterstatus) # try to update; ignore errors.
      return self.status
    end

    # At this point here then, clusterstatus == "Does Not Exist"
    if ar_status.match(/^(On CPU|Suspended|On Hold|Queued)$/)
      self.status_transition(self.status,"Data Ready") # try to update; ignore errors.
      return self.status
    end

    cb_error "Cluster job finished with unknown Active Record status #{ar_status} and Cluster status #{clusterstatus}"
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
    CbrainTask.transaction do
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
      Scir::Session.session_cache.terminate(self.cluster_jobid)
      self.status = "Terminated"
    rescue
      # nothing to do
    end
  end

  #Suspend the task (if it's currently in an appropriate state.)
  def suspend
    return unless self.status == "On CPU"
    begin
      Scir::Session.session_cache.suspend(self.cluster_jobid)
      self.status = "Suspended"
    rescue
      # nothing to do
    end
  end

  #Resume processing the task if it was suspended.
  def resume
    begin
      return unless self.status == "Suspended"
      Scir::Session.session_cache.resume(self.cluster_jobid)
      self.status = "On CPU"
    rescue
      # nothing to do
    end
  end

  #Put the task on hold if it is currently queued.
  def hold
    return unless self.status == "Queued"
    begin
      Scir::Session.session_cache.hold(self.cluster_jobid)
      self.status = "On Hold"
    rescue
      # nothing to do
    end
  end

  #Release the task from a suspended state.
  def release
    begin
      return unless self.status == "Suspended"
      Scir::Session.session_cache.release(self.cluster_jobid)
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
      task = CbrainTask.find(task_id) rescue nil
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



  ##################################################################
  # ActiveRecord Lifecycle methods
  ##################################################################

  # All object destruction also implies termination!
  def before_destroy #:nodoc:
    self.terminate
    self.remove_cluster_workdir
  end



  ##################################################################
  # Cluster Job's STDOUT And STDERR Files Methods
  ##################################################################

  # Returns the filename for the job's captured STDOUT
  # Returns nil if the work directory has not yet been
  # created, or no longer exists. The file itself is not
  # garanteed to exist, either.
  def stdout_cluster_filename(run_number=nil)
    workdir = self.cluster_workdir
    return nil unless workdir
    if File.exists?("#{workdir}/.qsub.sh.out") # for compatibility will old tasks
      "#{workdir}/.qsub.sh.out"                # for compatibility will old tasks
    else
      "#{workdir}/#{QSUB_STDOUT_BASENAME}.#{self.run_id(run_number)}" # New official convention
    end
  end

  # Returns the filename for the job's captured STDERR
  # Returns nil if the work directory has not yet been
  # created, or no longer exists. The file itself is not
  # garanteed to exist, either.
  def stderr_cluster_filename(run_number=nil)
    workdir = self.cluster_workdir
    return nil unless workdir
    if File.exists?("#{workdir}/.qsub.sh.err") # for compatibility will old tasks
      "#{workdir}/.qsub.sh.err"                # for compatibility will old tasks
    else
      "#{workdir}/#{QSUB_STDERR_BASENAME}.#{self.run_id(run_number)}" # New official convention
    end
  end

  # Read back the STDOUT and STDERR files for the job, and
  # store (part of) their contents in the task's object;
  # this is called explicitely only in the case when the
  # portal performs a 'show' request on a single task
  # otherise it's too expensive to do it every time. The
  # pseudo attributes :cluster_stdout and :cluster_stderr
  # are not really part of the task's ActiveRecord model.
  def capture_job_out_err(run_number=nil)
     self.cluster_stdout=nil
     self.cluster_stderr=nil
     return if self.new_record?
     stdoutfile = self.stdout_cluster_filename(run_number)
     stderrfile = self.stderr_cluster_filename(run_number)
     if stdoutfile && File.exist?(stdoutfile)
        io = IO.popen("tail -1000 #{stdoutfile}","r")
        self.cluster_stdout = io.read
        io.close
     end
     if stderrfile && File.exist?(stderrfile)
        io = IO.popen("tail -1000 #{stderrfile}","r")
        self.cluster_stderr = io.read
        io.close
     end
  end



  ##################################################################
  # Cluster Task Status Update Methods
  ##################################################################

  protected

  # The list of possible cluster states is larger than
  # the ones we need for CBRAIN, so here is a mapping
  # to our shorter list. Note that when a job finishes
  # on the cluster, we cannot tell whether it was all
  # correctly done or not, so we only have "Does Not Exist"
  # as a state. It's up to the subclass' save_results()
  # to figure out if the processing was successfull or
  # not.
  @@Cluster_States_To_Status ||= {
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
  # as a non-existing cluster job might mean a job not started,
  # a killed job or a job that's exited properly, and we can't determine
  # which of the three from the job_ps()
  def cluster_status
    state = Scir::Session.session_cache.job_ps(self.cluster_jobid,self.updated_at)
    status = @@Cluster_States_To_Status[state] || "Does Not Exist"
    return status
  end



  ##################################################################
  # Cluster Task Creation Methods
  ##################################################################

  # Submit the actual job request to the cluster management software.
  # Expects that the WD has already been changed.
  def submit_cluster_job
    self.addlog("Launching job on cluster.")

    name     = self.name
    commands = self.cluster_commands  # Supplied by subclass; can use self.params
    workdir  = self.cluster_workdir

    # Special case of RUBY-only jobs (jobs that have no cluster-side).
    # In this case, only the 'Setting Up' and 'Post Processing' states
    # are actually performed.
    if commands.nil? || commands.size == 0
      self.addlog("No BASH commands associated with this task. Jumping to state 'Data Ready'.")
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
        "export PATH=\"#{RAILS_ROOT + "/vendor/cbrain/bin"}:$PATH\"\n" +
        commands.join("\n") +
        "\n"
      )
    end

    # Create the cluster job object
    Scir::Session.session_cache   # Make sure it's loaded.
    job = Scir::JobTemplate.new_jobtemplate
    job.command = "/bin/bash"
    job.arg     = [ qsubfile ]
    job.stdout  = ":" + self.stdout_cluster_filename
    job.stderr  = ":" + self.stderr_cluster_filename
    job.join    = false
    job.wd      = workdir
    job.name    = name

    # Log version of Scir lib
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
    self.addlog("Implementation in file '#{impl_file}' by '#{impl_author}' revision '#{impl_rev}' from '#{impl_date + " " + impl_time}'.")

    # Queue the job and return true, at this point
    # it's not our 'job' to figure out if it worked
    # or not.
    jobid              = Scir::Session.session_cache.run(job)
    self.cluster_jobid = jobid
    self.status        = "Queued"
    self.addlog("Queued as job ID '#{jobid}'.")
    self.save

    return true
  end



  ##################################################################
  # Cluster Job Shared Work Directory Methods
  ##################################################################

  # Create the directory in which to run the job.
  # If the task contains the ID of another task in
  # the attribute :share_wd_tid, then that other
  # task's work directory will be used instead.
  def make_cluster_workdir
    # Use the work directory of another task
    otask_id = self.share_wd_tid
    if ! otask_id.blank?
      otask = CbrainTask.find(otask_id)
      cb_error "Cannot use the work directory of a task that belong to another Bourreau." if otask.bourreau_id != self.bourreau_id
      owd   = otask.cluster_workdir
      cb_error "Cannot find the work directory of other task '#{otask_id}'."      if owd.blank?
      cb_error "The work directory '#{owd} of task '#{otask_id}' does not exist." unless File.directory?(owd)
      self.cluster_workdir = owd
      self.addlog("Using workdir '#{owd}' of task '#{otask.bname_tid}'.")
      return
    end

    # Create our own work directory
    name = self.name
    user = self.user.login
    self.cluster_workdir = (CBRAIN::CLUSTER_sharedir + "/" + "#{user}-#{name}-P" + Process.pid.to_s + "-I" + self.id.to_s)
    self.addlog("Trying to create workdir '#{self.cluster_workdir}'.")
    Dir.mkdir(self.cluster_workdir,0700) unless File.directory?(self.cluster_workdir)
  end

  # Remove the directory created to run the job.
  def remove_cluster_workdir
    unless self.cluster_workdir.blank?
      self.addlog("Removing workdir '#{self.cluster_workdir}'.")
      FileUtils.remove_dir(self.cluster_workdir, true)
      #system("/bin/rm -rf \"#{self.cluster_workdir}\" >/dev/null 2>/dev/null")
      self.cluster_workdir = nil
    end
  end

end

# Patch: pre-load all model files for the subclasses
Dir.chdir(File.join(RAILS_ROOT, "app", "models", "cbrain_task")) do
  Dir.glob("*.rb").each do |model|      
    model.sub!(/.rb$/,"")
    unless CbrainTask.const_defined? model.classify
      require_dependency "cbrain_task/#{model}.rb"
      #puts ">>>> #{model} #{model.classify}"
    end
  end
end

