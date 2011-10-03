
#
# CBRAIN Project
#
# Bourreau CbrainTask Wrapper Class
#
# Original author: Pierre Rioux
#
# $Id$
#

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

  Revision_info=CbrainFileRevision[__FILE__]

  include NumericalSubdirTree

  # These basenames might get modified with suffixes appended to them.
  QSUB_SCRIPT_BASENAME = ".qsub"      # appended: ".{name}.{id}.sh"
  QSUB_STDOUT_BASENAME = ".qsub.out"  # appended: ".{name}.{id}"
  QSUB_STDERR_BASENAME = ".qsub.err"  # appended: ".{name}.{id}"

  before_destroy :before_destroy_terminate_and_rm_workdir

  ##################################################################
  # Core Object Methods
  ##################################################################

  # Automatically register the task's version when new() is invoked.
  def initialize(arguments = {}) #:nodoc:
    res = super(arguments)
    self.record_cbraintask_revs
    res
  end

  # Records the revision number of ClusterTask and the
  # revision number of the its specific subclass.
  def record_cbraintask_revs #:nodoc:
    baserev = ClusterTask::Revision_info
    subrev  = self.revision_info
    self.addlog("#{baserev.svn_id_file} rev. #{baserev.svn_id_rev}")
    self.addlog("#{subrev.svn_id_file} rev. #{subrev.svn_id_rev}")
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

  # This method can be redefined in a subclass;
  # it will be called by the framework to query
  # a task and get an estimate of how long the
  # task will run. This is used when submitting the
  # job on the cluster. The value returned by a
  # CbrainTask should be conservative and be reasonably
  # larger than the longest run expected, without being
  # overly excessive. The default value used by
  # the framework is 24.hours
  def job_walltime_estimate
    24.hours
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
    self.addlog("This task is not programmed for recovery.")
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
    self.addlog("This task is not programmed for recovery.")
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
    self.addlog("This task is not programmed for recovery.")
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
    self.addlog("This task is not programmed for restarts.")
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
    self.addlog("This task is not programmed for restarts.")
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
    self.addlog("This task is not programmed for restarts.")
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
    relpath = relpath.to_s
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
    original_entry = original_entry.to_s
    relpath        = relpath.to_s
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
  # containing at the minimum :name and :data_provider_id.
  # The :user_id and :group_id default to the task's.
  def safe_userfile_find_or_new(klass,attlist)
    attlist[:data_provider_id] ||= self.results_data_provider_id
    cb_error "Class for file must be a subclass of Userfile." unless
      klass < Userfile
    cb_error "Attribute list missing a required attribute." unless
      [ :name, :data_provider_id ].all? { |i| ! attlist[i].blank? } # minimal set!
    unless attlist.has_key?(:user_id)
      cb_error "Cannot assign user to file." unless self.user_id
      attlist[:user_id] = self.user_id
    end
    group_id_for_file = attlist.delete(:group_id) || self.group_id # is re-assigned later
    cb_error "Cannot assign group to file." unless group_id_for_file
    results = klass.where( attlist ).all
    if results.size == 1
      existing_userfile = results[0]
      existing_userfile.cache_is_newer # we assume we want to update the content, always
      existing_userfile.group_id = group_id_for_file # crush or reset group
      return existing_userfile
    end
    cb_error "Found more than one file that match attribute list: '#{attlist.inspect}'." if results.size > 1
    attlist[:group_id] = group_id_for_file
    return klass.new(attlist)
  end

  def we_are_in_workdir #:nodoc:
    full = self.full_cluster_workdir
    return false if full.blank?
    cur_dir = Dir.getwd
    Dir.chdir(full) do  # We need to do this in case the workdir goes through symlinks...
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
    mylink   = "/tasks/#{self.id}"  # can't use show_task_path() on Bourreau side
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
    mylink   = "/tasks/#{self.id}" # can't use show_task_path() on Bourreau side
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
    mylink   = "/tasks/#{self.id}"  # can't use show_task_path() on Bourreau side
    mymarkup = "[[#{myname}][#{mylink}]]"
    creatorlist.each do |creator|
      next unless creator.is_a?(Userfile) && creator.id
      creatormarkup = "[[#{creator.name}][/userfiles/#{creator.id}]]" # can't use userfile_path() on Bourreau side
      createdlist.each do |created|
        next unless created.is_a?(Userfile) && created.id
        createdmarkup = "[[#{created.name}][/userfiles/#{created.id}]]" # can't use userfile_path() on Bourreau side
        creator.addlog_context(self, "Used by task #{mymarkup} to create #{createdmarkup} #{comment}", 5)
        created.addlog_context(self, "Created by task #{mymarkup} from #{creatormarkup} #{comment}",   5)
      end
    end
  end

  # This method is the equivalent of running a system() call
  # with the output captured, but where the supplied command
  # will be executed within the full environment context defined
  # for the task (that is, environment variables AND bash
  # prologues will have been executed before the +command+ ).
  # The +command+ itself can be a multi line script if needed,
  # as it will be appended to a longer script that wil be passed
  # to bash. The method returns an array of two strings,
  # the STDOUT and STDERR produced by the internally
  # generated script.
  #
  # Note that the script is executed in the task's work
  # directory, even though its text is stored in "/tmp".
  def tool_config_system(command)

    cb_error "Current directory is not the task's work directory?" unless self.we_are_in_workdir

    # Defines tmp file paths
    scriptfile = "/tmp/tool_script.#{$$}.#{Time.now.to_i}"
    outfile    = "#{scriptfile}.out"
    errfile    = "#{scriptfile}.err"

    # Find the tool configuration in effect
    # We need three objects, each can be nil.
    bourreau_glob_config = self.bourreau.global_tool_config
    tool_glob_config     = self.tool.global_tool_config
    tool_config          = self.tool_config

    # Build script
    script  = ""
    script += bourreau_glob_config.to_bash_prologue if bourreau_glob_config
    script += tool_glob_config.to_bash_prologue     if tool_glob_config
    script += tool_config.to_bash_prologue          if tool_config
    script += self.supplemental_cbrain_tool_config_init
    script += "\n\n" + command + "\n\n"
    File.open(scriptfile,"w") { |fh| fh.write(script) }

    # Execute and capture
    system("/bin/bash '#{scriptfile}' </dev/null >'#{outfile}' 2>'#{errfile}'")
    out = File.read(outfile) rescue ""
    err = File.read(errfile) rescue ""
    return [ out, err ]

  ensure
    File.unlink(scriptfile) rescue true
    File.unlink(outfile)    rescue true
    File.unlink(errfile)    rescue true
  end

  # Used to add some more initialization code specific to
  # the CBRAIN system itself, after all other tool_config
  # initalizations. Returns a few lines of BASH code as
  # a single string. If overrriden in subclasses, make sure
  # to append the bash code to the one returned by super()!
  def supplemental_cbrain_tool_config_init #:nodoc:
    "\n" +
    "# CBRAIN Bourreau-side initializations\n" +
    "export PATH=\"#{Rails.root.to_s + "/vendor/cbrain/bin"}:$PATH\"\n"
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
      self.record_cbraintask_revs
      self.make_cluster_workdir
      self.apply_tool_config_environment
      Dir.chdir(self.full_cluster_workdir) do
        if ! self.setup  # as defined by subclass
          self.addlog("Failed to setup: 'false' returned by setup().")
          self.status_transition(self.status, "Failed To Setup")
        elsif ! self.submit_cluster_job
          self.addlog("Failed to start: 'false' returned by submit_cluster_job().")
          self.status_transition(self.status, "Failed To Setup")
        else
          self.addlog("Setup and submit process successful.")
          # the status is moving forward at its own pace now
        end
      end
    rescue Exception => e
      self.addlog_exception(e,"Exception raised while setting up:")
      self.status_transition(self.status, "Failed To Setup")
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
      self.record_cbraintask_revs
      self.update_size_of_cluster_workdir
      self.apply_tool_config_environment
      saveok = false
      Dir.chdir(self.full_cluster_workdir) do
        # Call the subclass-provided save_results()
        saveok = self.save_results
      end
      if ! saveok
        self.status_transition(self.status, "Failed On Cluster")
        self.addlog("Data processing failed on the cluster.")
      else
        self.addlog("Asynchronous postprocessing completed.")
        self.status_transition(self.status, "Completed")
      end
    rescue Exception => e
      self.addlog_exception(e,"Exception raised while post processing results:")
      self.status_transition(self.status, "Failed To PostProcess")
    end

    self.save
  end

  # Possible returned status values:
  # [<b>New</b>] The task is new and not yet set up.
  # [<b>Standby</b>] The task just exists; getting out of this state is up to the process which set it thus.
  # [<b>Setting Up</b>] The task is in its asynchronous 'setup' state.
  # [<b>Configured</b>] The task has been set up but NOT launched on cluster.
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

    # The list below contains states that are either final
    # or are are moved to other states using other mechanism
    # than a check with the cluster's state. For instance:
    # - "Data Ready" which can be moved to "Post Processing"
    #    through the method call save_results()
    # - "Post Processing" which will be moved to "Completed"
    #    through the method call save_results()
    return ar_status if ar_status.match(/^(Duplicated|Standby|New|Setting Up|Configured|Failed.*|Data Ready|Terminated|Completed|Post Processing|Recover|Restart|Preset)$/)

    # This is the expensive call, the one that queries the cluster.
    clusterstatus = self.cluster_status
    return self.status if clusterstatus.blank?  # this means the cluster can't tell us, for some reason.
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



  ##################################################################
  # Task Control Methods
  # (hold, suspend, terminate, etc etc)
  ##################################################################

  #Terminate the task (if it's currently in an appropriate state.)
  def terminate
    cur_status = self.status

    # Cluster job termination
    if cur_status.match(/^(On CPU|On Hold|Suspended|Queued)$/)
      self.scir_session.terminate(self.cluster_jobid)
      return self.status_transition(cur_status,"Terminated")
    end

    # New tasks are simply marked as Terminated
    if cur_status == "New"
      return self.status_transition(cur_status,"Terminated")
    end

    # Stuck or lost jobs executing Ruby code
    if self.updated_at < 8.hours.ago && cur_status.match(/^(Setting Up|Post Processing|Recovering|Restarting)/)
      case cur_status
        when "Setting Up"
          self.status_transition(self.status, "Failed To Setup")
        when "Post Processing"
          self.status_transition(self.status, "Failed To PostProcess")
        when /(Recovering|Restarting) (\S+)/
          fromwhat = Regexp.last_match[2]
          self.status_transition(self.status, "Failed To Setup")       if fromwhat == 'Setup'
          self.status_transition(self.status, "Failed On Cluster")     if fromwhat == 'Cluster'
          self.status_transition(self.status, "Failed To PostProcess") if fromwhat == 'PostProcess'
        else
          self.status_transition(self.status, "Terminated")
      end
      self.addlog("Terminating a task that is too old and stuck at '#{cur_status}'; now at '#{self.status}'")
      return self.save
    end

    # Otherwise, we don't do nothin'
    return false
  rescue
    false
  end

  # Suspend the task (if it's currently in an appropriate state.)
  def suspend
    return false unless self.status == "On CPU"
    begin
      self.scir_session.suspend(self.cluster_jobid)
      self.status_transition(self.status, "Suspended")
    rescue
      false
    end
  end

  # Resume processing the task if it was suspended.
  def resume
    begin
      return false unless self.status == "Suspended"
      self.scir_session.resume(self.cluster_jobid)
      self.status_transition(self.status, "On CPU")
    rescue
      false
    end
  end

  # Put the task on hold if it is currently queued.
  def hold
    return false unless self.status == "Queued"
    begin
      self.scir_session.hold(self.cluster_jobid)
      self.status_transition(self.status, "On Hold")
    rescue
      false
    end
  end

  # Release the task from state On Hold.
  def release
    begin
      return false unless self.status == "On Hold"
      self.scir_session.release(self.cluster_jobid)
      self.status_transition(self.status, "Queued")
    rescue
      false
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
      self.status_transition(self.status, "New")        if failed_where == "Setup"
      self.status_transition(self.status, "Data Ready") if failed_where == "PostProcess"
      return self.save
    end
    begin
      return false unless curstat =~ /^Failed (To Setup|On Cluster|To PostProcess)$/
      failedwhen = Regexp.last_match[1]
      self.addlog("Scheduling recovery from '#{curstat}'.")
      self.status_transition(self.status, "Recover Setup")       if failedwhen == "To Setup"
      self.status_transition(self.status, "Recover Cluster")     if failedwhen == "On Cluster"
      self.status_transition(self.status, "Recover PostProcess") if failedwhen == "To PostProcess"
      return self.save
    rescue
      false
    end
  end

  # This triggers the restart mechanism for all Completed tasks.
  # This simply sets a special value in the 'status' field
  # that will be handled by the Bourreau Worker. The +atwhat+
  # argument must be exactly one of "Setup", "Cluster" or "PostProcess".
  def restart(atwhat = "Setup")
    begin
      return false unless self.status =~ /Completed|Terminated|Duplicated/
      return false unless atwhat =~ /^(Setup|Cluster|PostProcess)$/
      atwhat = "Setup" if self.status =~ /Terminated|Duplicated/ # forced
      self.addlog("Scheduling restart at '#{atwhat}'.")
      return self.status_transition(self.status, "Restart #{atwhat}") # will be handled by worker
    rescue
      false
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
  def before_destroy_terminate_and_rm_workdir #:nodoc:
    self.terminate rescue true
    self.remove_cluster_workdir
    true
  end



  ##################################################################
  # Cluster Job's STDOUT And STDERR Files Methods
  ##################################################################

  # Returns a basename for the QSUB script for the task.
  # This is not a full path, just a filename relative to the work directory.
  # The file itself is not garanteed to exist.
  def qsub_script_basename(run_number=nil)
    workdir = self.full_cluster_workdir || "/does_not_exist_never_mind"
    if File.exists?("#{workdir}/#{QSUB_SCRIPT_BASENAME}.#{self.run_id(run_number)}.sh") # for compat
      "#{QSUB_SCRIPT_BASENAME}.#{self.run_id(run_number)}.sh"
    else
      "#{QSUB_SCRIPT_BASENAME}.#{self.name}.#{self.run_id(run_number)}.sh" # New official convention
    end
  end

  # Returns the filename for the job's captured STDOUT
  # Returns nil if the work directory has not yet been
  # created, or no longer exists. The file itself is not
  # garanteed to exist, either.
  def stdout_cluster_filename(run_number=nil)
    workdir = self.full_cluster_workdir
    return nil if workdir.blank?
    if File.exists?("#{workdir}/.qsub.sh.out") # for compatibility will old tasks
      "#{workdir}/.qsub.sh.out"
    elsif File.exists?("#{workdir}/#{QSUB_STDOUT_BASENAME}.#{self.run_id(run_number)}") # for compat
      "#{workdir}/#{QSUB_STDOUT_BASENAME}.#{self.run_id(run_number)}"
    else
      "#{workdir}/#{QSUB_STDOUT_BASENAME}.#{self.name}.#{self.run_id(run_number)}" # New official convention
    end
  end

  # Returns the filename for the job's captured STDERR
  # Returns nil if the work directory has not yet been
  # created, or no longer exists. The file itself is not
  # garanteed to exist, either.
  def stderr_cluster_filename(run_number=nil)
    workdir = self.full_cluster_workdir
    return nil if workdir.blank?
    if File.exists?("#{workdir}/.qsub.sh.err") # for compatibility will old tasks
      "#{workdir}/.qsub.sh.err"
    elsif File.exists?("#{workdir}/#{QSUB_STDERR_BASENAME}.#{self.run_id(run_number)}") # for compat
      "#{workdir}/#{QSUB_STDERR_BASENAME}.#{self.run_id(run_number)}"
    else
      "#{workdir}/#{QSUB_STDERR_BASENAME}.#{self.name}.#{self.run_id(run_number)}" # New official convention
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
     self.cluster_stdout = nil
     self.cluster_stderr = nil
     self.script_text    = nil
     return if self.new_record?
     stdoutfile = self.stdout_cluster_filename(run_number)
     stderrfile = self.stderr_cluster_filename(run_number)
     scriptfile = Pathname.new(self.full_cluster_workdir) + self.qsub_script_basename(run_number) rescue nil
     if stdoutfile && File.exist?(stdoutfile)
        io = IO.popen("tail -2000 #{stdoutfile}","r")
        self.cluster_stdout = io.read
        io.close
     end
     if stderrfile && File.exist?(stderrfile)
        io = IO.popen("tail -2000 #{stderrfile}","r")
        self.cluster_stderr = io.read
        io.close
     end
     if scriptfile && File.exist?(scriptfile.to_s)
        self.script_text = File.read(scriptfile.to_s) rescue ""
     end
     true
  end



  ##################################################################
  # Cluster Task Status Update Methods
  ##################################################################

  protected

  # Returns the class name which implements this
  # Bourreau's cluster management system interface.
  # This is really a property of the whole Rails app,
  # but it's provided here in the model for convenience.
  def self.scir_class #:nodoc:
    @scir_class   ||= RemoteResource.current_resource.scir_class
  end

  # Returns the object which implements this
  # Bourreau's cluster management system's session.
  # This is really a property of the whole Rails app,
  # but it's provided here in the model for convenience.
  def self.scir_session #:nodoc:
    @scir_session ||= RemoteResource.current_resource.scir_session
  end

  # Returns the class name which implements this
  # Bourreau's cluster management system interface.
  # This is really a property of the whole Rails app,
  # but it's provided here in the model for convenience.
  def scir_class #:nodoc:
    self.class.scir_class
  end

  # Returns the object which implements this
  # Bourreau's cluster management system's session.
  # This is really a property of the whole Rails app,
  # but it's provided here in the model for convenience.
  def scir_session #:nodoc:
    self.class.scir_session
  end

  # The list of possible cluster states is different than
  # the ones we need for CBRAIN, so here is a mapping
  # to our shorter list. Note that when a job finishes
  # on the cluster, we cannot tell whether it was all
  # correctly done or not, so we only have "Does Not Exist"
  # as a state. It's up to the subclass' save_results()
  # to figure out if the processing was successful or
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
    state = self.scir_session.job_ps(self.cluster_jobid,self.updated_at)
    status = @@Cluster_States_To_Status[state] || "Does Not Exist"
    return status
  rescue => ex
    logger.error("Cannot get cluster status for #{self.scir_session.class} ?!?") rescue nil
    logger.error("Exception was: #{ex.class} : #{ex.message}")                   rescue nil
    nil
  end



  ##################################################################
  # Cluster Task Creation Methods
  ##################################################################

  # Apply the environment variables configured in
  # the ToolConfig objects in effect for this job.
  def apply_tool_config_environment
    # Find the tool configuration in effect
    # We need three objects, each can be nil.
    bourreau_glob_config = self.bourreau.global_tool_config
    tool_glob_config     = self.tool.global_tool_config
    tool_config          = self.tool_config

    bourreau_glob_config.apply_environment(:extended) if bourreau_glob_config
    tool_glob_config.apply_environment(:extended)     if tool_glob_config
    tool_config.apply_environment(:extended)          if tool_config
  end

  # Submit the actual job request to the cluster management software.
  # Expects that the WD has already been changed.
  def submit_cluster_job
    self.addlog("Launching job on cluster.")

    name     = self.name
    commands = self.cluster_commands  # Supplied by subclass; can use self.params
    workdir  = self.full_cluster_workdir

    # Special case of RUBY-only jobs (jobs that have no cluster-side).
    # In this case, only the 'Setting Up' and 'Post Processing' states
    # are actually performed.
    if commands.blank? || commands.all? { |l| l.blank? }
      self.addlog("No BASH commands associated with this task. Jumping to state 'Data Ready'.")
      self.status_transition(self.status, "Data Ready")  # Will trigger Post Processing later on.
      self.save
      return true
    end

    # Find the tool configuration in effect
    # We need three objects, each can be nil.
    bourreau_glob_config = self.bourreau.global_tool_config
    tool_glob_config     = self.tool.global_tool_config
    tool_config          = self.tool_config
    bourreau_glob_config = nil if bourreau_glob_config && bourreau_glob_config.is_trivial?
    tool_glob_config     = nil if tool_glob_config     && tool_glob_config.is_trivial?
    tool_config          = nil if tool_config          && tool_config.is_trivial?
    self.addlog("Bourreau Global Config: ID=#{bourreau_glob_config.id}")                if bourreau_glob_config
    self.addlog("Tool Global Config: ID=#{tool_glob_config.id}")                        if tool_glob_config
    self.addlog("Tool Version: ID=#{tool_config.id}, #{tool_config.short_description}") if tool_config

    # Create a bash command script out of the text
    # lines supplied by the subclass
    script = <<-QSUB_SCRIPT
#!/bin/sh

# Script created automatically by #{self.class.to_s}
# #{Revision_info}

#{bourreau_glob_config ? bourreau_glob_config.to_bash_prologue : ""}
#{tool_glob_config     ? tool_glob_config.to_bash_prologue     : ""}
#{tool_config          ? tool_config.to_bash_prologue          : ""}
#{self.supplemental_cbrain_tool_config_init}

# CbrainTask '#{self.name}' commands section

#{commands.join("\n")}

    QSUB_SCRIPT
    qsubfile = self.qsub_script_basename
    File.open(qsubfile,"w") do |io|
      io.write( script )
    end

    # Create the cluster job object
    scir_class   = self.scir_class
    scir_session = self.scir_session
    job          = Scir.job_template_builder(scir_class)
    job.command  = "/bin/bash"
    job.arg      = [ qsubfile ]
    job.stdout   = ":" + self.stdout_cluster_filename
    job.stderr   = ":" + self.stderr_cluster_filename
    job.join     = false
    job.wd       = workdir
    job.name     = self.tname_tid  # "#{self.name}-#{self.id}" # some clusters want all names to be different!
    job.walltime = self.job_walltime_estimate

    # Log version of Scir lib
    drm     = scir_class.drm_system
    version = scir_class.version
    impl    = scir_class.drmaa_implementation
    self.addlog("Using Scir for '#{drm}' version '#{version}' implementation '#{impl}'.")

    impl_revinfo = scir_session.revision_info
    impl_file    = impl_revinfo.svn_id_file
    impl_rev     = impl_revinfo.svn_id_rev
    impl_author  = impl_revinfo.svn_id_author
    impl_date    = impl_revinfo.svn_id_date
    impl_time    = impl_revinfo.svn_id_time
    self.addlog("Implementation in file '#{impl_file}' by '#{impl_author}' rev. '#{impl_rev}' from '#{impl_date + " " + impl_time}'.")

    # Erase leftover STDOUT and STDERR files; necessary
    # because some cluster management systems just append
    # to them, which can confuse CBRAIN tasks trying to parse
    # them at PostProcessing.
    File.unlink(self.stdout_cluster_filename) rescue true
    File.unlink(self.stderr_cluster_filename) rescue true

    # Some jobs are meant only to be fully configured by never actually submitted.
    if self.meta[:configure_only]
      self.addlog("This task is meant to be configured but not actually submitted.")
      self.status_transition(self.status, "Configured")
    else
      # Queue the job on the cluster and return true, at this point
      # it's not our 'job' to figure out if it worked or not.
      self.addlog("Cluster command: #{job.qsub_command}") if self.user.login == 'admin'
      jobid              = scir_session.run(job)
      self.cluster_jobid = jobid
      self.status_transition(self.status, "Queued")
      self.addlog("Queued as job ID '#{jobid}'.")
    end
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

    # Test to see if it already exists; if so, use it.
    current = self.cluster_workdir
    if ! current.blank?
      full = self.full_cluster_workdir
      return true if File.directory?(full)
      self.cluster_workdir = nil # nihilate it
    end

    # Use the work directory of another task
    otask_id = self.share_wd_tid
    if ! otask_id.blank?
      otask = CbrainTask.find_by_id(otask_id)
      cb_error "Task '#{self.bname_tid}' is supposed to use the workdir of task '#{otask_id}' which doesn't exist." if ! otask
      cb_error "Cannot use the work directory of a task that belong to another Bourreau." if otask.bourreau_id != self.bourreau_id
      owd   = otask.full_cluster_workdir
      cb_error "Cannot find the work directory of other task '#{otask_id}'."      if owd.blank?
      cb_error "The work directory '#{owd} of task '#{otask_id}' does not exist." unless File.directory?(owd)
      #self.cluster_workdir = File.basename(owd) # no longer assigned
      self.addlog("Using workdir '#{owd}' of task '#{otask.bname_tid}'.")
      return
    end

    # Create our own work directory
    name        = self.name
    user        = self.user.login
    basedir     = "#{user}-#{name}-T#{self.id}"
    rel_path    = self.class.numerical_subdir_tree_components(self.id).join("/")
    self.cluster_workdir = "#{rel_path}/#{basedir}" # newest convention is "00/12/34/basedir".
    fulldir = self.full_cluster_workdir # builds using the cluster_workdir and the bourreau's cms_shared_dir
    self.addlog("Trying to create workdir '#{fulldir}'.")
    self.class.mkdir_numerical_subdir_tree_components(self.cluster_shared_dir, self.id) # mkdir "00/12/34"
    Dir.mkdir(fulldir,0700) unless File.directory?(fulldir)
    true
  end

  # Remove the directory created to run the job.
  def remove_cluster_workdir
    cb_error "Tried to remove a task's work directory while in the wrong Rails app." unless
      self.bourreau_id == CBRAIN::SelfRemoteResourceId
    return true if ! self.share_wd_tid.blank?  # Do not erase if using some other task's workdir.
    full=self.full_cluster_workdir
    return if full.blank?
    self.addlog("Removing workdir '#{full}'.")
    FileUtils.remove_dir(full, true) rescue true
    self.class.rmdir_numerical_subdir_tree_components(self.cluster_shared_dir, self.id) rescue true
    self.cluster_workdir = nil
    true
  end

  # Compute size in bytes of the work directory; save it in the task's
  # attribute :cluster_workdir_size . Leaves nil if the directory doesn't
  # exist or any error occured. Sets to '0' if the task uses another task's
  # work directory.
  def update_size_of_cluster_workdir
    if self.share_wd_tid
      self.cluster_workdir_size = 0
      self.save
      return
    end
    full=self.full_cluster_workdir
    self.cluster_workdir_size = nil
    if ( ! full.blank? ) && Dir.exists?(full)
      sizeline = IO.popen("du -s -k '#{full}'","r") { |fh| fh.readline rescue "" }
      if mat = sizeline.match(/^\s*(\d+)/) # in Ks
        self.cluster_workdir_size = mat[1].to_i.kilobytes
        self.addlog("Size of work directory: #{self.cluster_workdir_size} bytes.")
      end
    end
    self.save
    return self.cluster_workdir_size
  rescue
    return nil
  end

end

# Patch: pre-load all model files for the subclasses
Dir.chdir(CBRAIN::TasksPlugins_Dir) do
  Dir.glob("*.rb").each do |model|
    next if model == "cbrain_task_class_loader.rb"
    model.sub!(/.rb$/,"")
    unless CbrainTask.const_defined? model.classify
      #puts_blue "Loading CbrainTask subclass #{model.classify} from #{model}.rb ..."
      require_dependency "#{CBRAIN::TasksPlugins_Dir}/#{model}.rb"
    end
  end
end

