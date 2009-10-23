
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
#[<b>drmaa_jobid</b>] The job id of the running task.
#[<b>drmaa_workdir</b>] The directory in which the task is running.
#[<b>params</b>] A hash of the parameters sent in the job request from BrainPortal.
#[<b>status</b>] The status of the current task.
#[<b>log</b>] A log of tasks progress.
#[<b>user_id</b>] The id of the user who requested this task.
#[<b>bourreau_id</b>] The id of the Bourreau on which the task is running.
#
#<b>DrmaaTask should not be instantiated directly.</b> Instead, subclasses of DrmaaTask should be created to 
#represent requests for specific processing tasks. 
#These are *ActiveRecord* models, meaning they do access the database directly. 
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

  # The attribute 'params' is a serialized hash table
  # containing job-specific parameters; it's up to each
  # subclass of DrmaaTask to find/use/define its content
  # as necessary.
  serialize :params

public

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
  # two that are of use are self.params and
  # self.drmaa_workdir (and, graciously, when
  # this method is called, it's already the current
  # working directory).
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
  # Main Controller Methods (mainly called by the tasks controller)
  # start_all(), post_process(), update_status()
  ##################################################################

  # This should be called only once when the object is new.
  # A temporary, grid-aware working directory is created
  # for the job.
  def start_all
    cb_error "Task is not 'New'" if self.status && self.status != 'New'
    self.addlog("Setting up.")
    self.status = "Setting Up"
    save_status = self.save

    # This used to be run in background, but now that
    # we have a worker subprocess, we no longer need
    # to have a spawn occur here.
      begin
        self.makeDRMAAworkdir
        Dir.chdir(self.drmaa_workdir) do
          if ! self.setup
            self.addlog("Failed To Setup")
            self.status = "Failed To Setup"
          else
            if ! self.run
              self.addlog("Failed To Start")
              self.status = "Failed To Start"
              #self.removeDRMAAworkdir
            end
          end
        end
      rescue => e
        self.addlog("Exception raised while setting up: #{e.class.to_s}: #{e.message}")
        e.backtrace.slice(0,10).each { |m| self.addlog(m) }
        self.status = "Failed To Setup"
      end

    self.save
  end

  # This is called
  # manually to finish processing a job that has
  # successfully run on the cluster. The main purpose
  # is to call the subclass' supplied save_result() method
  # then cleanup the temporary grid-aware directory.
  def post_process

    # Make sure job is ready.
    if self.status != "Data Ready"
      cb_error "post_process() called on a job that is not in Data Ready state"
    end

    self.addlog("Starting asynchronous postprocessing.")
    self.status = "Post Processing"
    self.save

    # Processing.
    # This used to be run in background, but now that
    # we have a worker subprocess, we no longer need
    # to have a spawn occur here.

      begin
        saveok = false
        Dir.chdir(self.drmaa_workdir) do
          # Call the subclass-provided save_results()
          saveok = self.save_results
        end
        if ! saveok
          self.status = "Failed To PostProcess"
        else
          self.addlog("Asynchronous postprocessing completed.")
          self.status = "Completed"
        end
      rescue Exception => e
        self.addlog("Exception raised while post processing results: #{e.class.to_s}: #{e.message}")
        e.backtrace.slice(0,10).each { |m| self.addlog(m) }
        self.status = "Failed To PostProcess"
      end

    self.save
  end

  # Possible returned status values:
  # [<b>New</b>] The task is new and not yet set up.
  # [<b>Setting Up</b>] The task is in its asynchronous 'setup' state.
  # [<b>Failed To *</b>]  (To Start, to Setup, etc) The task failed at some stage.
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
      cb_error "Unknown blank status obtained from Active Record"
    end

    # Final states that we can't get out of, except for:
    # - "Data Ready" which can be moved to "Post Processing"
    #    through the method call save_results()
    # - "Post Processing" which will be moved to "Completed"
    #    through the method call save_results()
    return ar_status if ar_status.match(/^(New|Setting Up|Failed.*|Data Ready|Terminated|Completed|Post Processing)$/)

    drmaastatus = self.drmaa_status
    #self.addlog("ar_status is #{ar_status} ; drmaa stat is #{drmaastatus}")

    # Steady states
    if drmaastatus.match(/^(On CPU|Suspended|On Hold|Queued)$/)
      self.status = drmaastatus
      self.save if ar_status != drmaastatus
      return drmaastatus
    end

    # At this point here then, drmaastatus == "Does Not Exist"
    if ar_status.match(/^(On CPU|Suspended|On Hold|Queued)$/)
      ar_status = self.status = "Data Ready"
      self.save
      return ar_status
    end

    cb_error "DRMAA job finished with unknown Active Record status #{ar_status} and DRMAA status #{drmaastatus}"
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

  #Capture any error output for the running job.
  def capture_job_out_err
     return if self.new_record?
     workdir = self.drmaa_workdir
     return unless workdir
     stdoutfile = "#{workdir}/.qsub.sh.out"
     stderrfile = "#{workdir}/.qsub.sh.err"
     #@capt_stdout_b64 = Base64.encode64(File.read(stdoutfile)) if File.exist?(stdoutfile)
     #@capt_stderr_b64 = Base64.encode64(File.read(stderrfile)) if File.exist?(stderrfile)
     if File.exist?(stdoutfile)
        #io = IO.popen("tail -30 #{stdoutfile} | fold -b -w 200 | tail -100","r")
        io = IO.popen("tail -100 #{stdoutfile}","r")
        @capt_stdout_b64 = Base64.encode64(io.read)
        io.close
     end
     if File.exist?(stderrfile)
        #io = IO.popen("tail -30 #{stderrfile} | fold -b -w 200 | tail -100","r")
        io = IO.popen("tail -100 #{stderrfile}","r")
        @capt_stderr_b64 = Base64.encode64(io.read)
        io.close
     end
  end



  ##################################################################
  # Utility Pseudo-Attributes Methods
  ##################################################################

  # Returns the task's User
  def user
    @user ||= User.find(self.user_id)
  end

  # Returns a simple name for the task (without the Drmaa prefix).
  def name
    @name ||= self.class.to_s.gsub(/^Drmaa/,"")
  end

  def bourreau
    # In development mode, the stupid RAILS zaps the constant.
    #@bourreau ||= CBRAIN::SelfRemoteResource || Bourreau.find(self.bourreau_id)
    @bourreau ||= Bourreau.find(self.bourreau_id)
  end

  # Returns an ID string containing both the bourreau_id +b+
  # and the task ID +t+ in format "b/t"
  def bid_tid
    @bid_tid ||= "#{self.bourreau_id || '?'}/#{self.id || '?'}"
  end

  # Returns an ID string containing both the bourreau_name +b+
  # and the task ID +t+ in format "b/t"
  def bname_tid
    @bname_tid ||= "#{self.bourreau.name || '?'}/#{self.id || '?'}"
    @bname_tid
  end



  ##################################################################
  # Protected Methods Start Here
  ##################################################################

  protected

  ##################################################################
  # Cluster Task Status Update Methods
  ##################################################################

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
  #---
  # Expects that the WD has already been changed.
  def run
    self.addlog("Launching DRMAA job.")

    name     = self.name
    commands = self.drmaa_commands  # Supplied by subclass; can use self.params
    workdir  = self.drmaa_workdir
    
    # Create a bash command script out of the text
    # lines supplied by the subclass
    qsubfile = ".qsub.sh"   # also used in post_process() !
    io = File.open(qsubfile,"w")

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
      "\n" )
    io.close

    # Create the DRMAA job object
    Scir::Session.session_cache   # Make sure it's loaded.
    job = Scir::JobTemplate.new_jobtemplate
    job.command = "/bin/bash"
    job.arg     = [ qsubfile ]
    job.stdout  = ":#{workdir}/#{qsubfile}.out"   # see also after_initialize() later
    job.stderr  = ":#{workdir}/#{qsubfile}.err"   # see also after_initialize() later
    job.join    = false
    job.wd      = workdir
    job.name    = name

    # Log version of DRMAA lib, e.g.
    # Using Scir for 'PBS/Torque' version '1.0' implementation 'PBS DRMAA v. 1.0 <http://sourceforge.net/projects/pbspro-drmaa/>'
    drm     = Scir.drm_system
    version = Scir.version
    impl    = Scir.drmaa_implementation
    self.addlog("Using Scir for '#{drm}' version '#{version}' implementation '#{impl}'")

    impl_revinfo = Scir::Session.session_cache.revision_info
    impl_file    = impl_revinfo.svn_id_file
    impl_rev     = impl_revinfo.svn_id_rev
    impl_author  = impl_revinfo.svn_id_author
    impl_date    = impl_revinfo.svn_id_date
    impl_time    = impl_revinfo.svn_id_time
    self.addlog("Implementation in file '#{impl_file}' revision '#{impl_rev}' from '#{impl_date + " " + impl_time}'")

    # Queue the job and return true, at this point
    # it's not our 'job' to figure out if it worked
    # or not.
    jobid            = Scir::Session.session_cache.run(job)
    jobid            = jobid.to_s.sub(/\.krylov.*/,".krylov.clumeq.mcgill.ca")
    self.drmaa_jobid = jobid
    self.status      = "Queued"
    self.addlog("Queued as job ID '#{jobid}'")
    return true

  end

  # Create the directory in which to run the job.
  def makeDRMAAworkdir
    name = self.name
    user = self.user.login
    self.drmaa_workdir = (CBRAIN::DRMAA_sharedir + "/" + "#{user}-#{name}-P" + $$.to_s + "-I" + self.id.to_s)
    self.addlog("Trying to create workdir '#{self.drmaa_workdir}'.")
    unless Dir.mkdir(self.drmaa_workdir,0700)
      cb_error "Cannot create directory '#{self.drmaa_workdir}': $!"
    end
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

  def capt_stdout_b64 #:nodoc:
    @capt_stdout_b64
  end

  def capt_stderr_b64 #:nodoc:
    @capt_stderr_b64
  end

end
