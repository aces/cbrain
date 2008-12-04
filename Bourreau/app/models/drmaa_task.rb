
#
# CBRAIN Project
#
# DRMAA Job Wrapper Class
#
# Original author: Pierre Rioux
#
# $Id$
#

require 'drmaa'
require 'logger'
require 'stringio'

# Used to launch new jobs
class CbrainDRMAAJob < DRMAA::JobTemplate
end

# This new class method caches the DRMAA::Session object;
# it's needed for initializing the constant class variable
# @@DRMAA_Session because only one Session object can be created
# during an active ruby execution, and mongrel reloads
# and reninitalizes all the rails classes at every request.
module DRMAA
  class Session
    def Session.session_cache
      @@session_cache ||= DRMAA::Session.new
    end
  end
end

# This is the core ActiveRecord functionality for
# launching GridEngine jobs using DRMAA; when a new
# application needs to be supported, it's only necessary
# to subclass DrmaaTask and provide the code for the three
# methods setup(), drmaa_commands() and save_results().
# They will be executed in a current working directory
# already setup for the cluster and automatically cleaned
# up after save_results() is called.
class DrmaaTask < ActiveRecord::Base

  Revision_info="$Id$"

  # The attribute 'params' is a serialized hash table
  # containing job-specific parameters; it's up to each
  # subclass of DrmaaTask to find/use/define its content
  # as necessary.
  serialize :params

public

  def initialize(arguments = {})
    super(arguments)
    self.addlog("#{Revision_info.svn_id_file} revision #{Revision_info.svn_id_rev}")
  end

  # This needs to be redefined in a subclass.
  # Returning true means that everything went fine
  # during setup; returning false will mark the
  # job with a final status "Failed To Setup".
  #
  # The method has of course access to all the
  # fields of the ActiveRecord, but the only
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
  # during result gathering; returning false will mark
  # the job with a final status "Failed To PostProcess".
  #
  # Like setup(), it has access to self.params and
  # self.drmaa_workdir
  def save_results
    true
  end

  # 'Saving' an object for the first time
  # automatically starts the job! Saving an
  # object further on will trigger an update,
  # which affects only the job's 'status'
  def save
    if self.status.blank?
      self.start_all
    end
    super
  end

  # 'Saving' an object for the first time
  # automatically starts the job! Saving an
  # object further on will trigger an update,
  # which affects only the job's 'status'
  def save!
    if self.status.blank?
      self.start_all
    end
    super
  end

  # This is called automatically when the object
  # is first saved. A temporary, grid-aware working
  # directory is created for the job.
  def start_all
    self.makeDRMAAworkdir
    Dir.chdir(self.drmaa_workdir) do
      self.addlog("Setting up.")
      unless self.setup
         self.addlog("Failed To Setup")
         self.status = "Failed To Setup"
         return self
      end
      unless self.run
         self.addlog("Failed To Start")
         self.status = "Failed To Start"
         self.removeDRMAAworkdir
         return self
      end
    end
    self
  end

  # This is called either automatically (todo) or
  # manually to finish processing a job that has
  # successfully run on the cluster. The main purpose
  # is to call the subclass' supplied save_result() method
  # then cleanup the temporary grid-aware directory.
  def post_process
    self.update_status
    self.addlog("Attempting PostProcessing")
    if self.status != "Data Ready"
      raise "post_process() called on a job that is not in Data Ready state"
    end
    saveok = false
    begin
      Dir.chdir(self.drmaa_workdir) do
        saveok = self.save_results
      end
    rescue => e
      self.addlog("Exception raised when saving results: #{e.inspect}")
    end
    self.removeDRMAAworkdir
    if ! saveok
      self.status = "Failed To PostProcess"
      return false
    else
      self.status = "Completed"
      return true
    end
  end

  # Possible returned status values:
  #  "Failed*"  (... To Start, To Setup, etc)
  #  "Queued"     "On CPU"    "Data Ready"  "Completed"
  #  "On Hold"    "Suspended"
  #  "Terminated"
  # The values are determined by BOTH the current state returned by
  # the cluster and the previously recorded value of status()
  # Some other values are reached by calling some methods, such as
  # post_process() which changes "Data Ready" to "Completed"
  def update_status

    ar_status = self.status
    if ar_status.blank?
      raise "Unknown blank status obtained from Active Record"
    end

    # Final states that we can't get out of
    # except for "Data Ready" which can be moved to "Completed"
    # through the method call save_results()
    return ar_status if ar_status.match(/^(Failed.*|Data Ready|Terminated|Completed)$/)

    drmaastatus = self.drmaa_status

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

    raise "DRMAA job finished with unknown Active Record status #{ar_status} and DRMAA status #{drmaastatus}"
  end

  def terminate
    return unless self.status.match(/^(On CPU|On Hold|Suspended|Queued)$/)
    begin
      @@DRMAA_session.terminate(self.drmaa_jobid)
      self.status = "Terminated"
    rescue
      # nothing to do
    end
  end

  def suspend
    return unless self.status == "On CPU"
    begin
      @@DRMAA_session.suspend(self.drmaa_jobid)
      self.status = "Suspended"
    rescue
      # nothing to do
    end
  end

  def resume
    begin
      return unless self.status == "Suspended"
      @@DRMAA_session.resume(self.drmaa_jobid)
      self.status = "On CPU"
    rescue
      # nothing to do
    end
  end

  def hold
    return unless self.status == "Queued"
    begin
      @@DRMAA_session.hold(self.drmaa_jobid)
      self.status = "On Hold"
    rescue
      # nothing to do
    end
  end

  def release
    begin
      return unless self.status == "Suspended"
      @@DRMAA_session.release(self.drmaa_jobid)
      self.status = "Queued"
    rescue
      # nothing to do
    end
  end

#  def addlog(message)
#    message = message.sub(/\s*$/,"\n")
#    log = self.log
#    log = "" if log.blank?
#    log += message
#    self.log = log
#  end

  def addlog(message)
    log = self.log
    log = "" if log.nil? || log.empty?
    log += 
      Time.now.strftime("[%Y-%m-%d %H:%M:%S] ") +
      message.sub(/\s*$/,"\n")
    self.log = log
  end

  # It is VERY important to add a pseudo-attribute 'type'
  # to the XML records created for the Drmaa* objects, as
  # this is used on the other end of an ActiveResource
  # connection to properly re-instanciate the object
  # with the proper type (see the patch to instantiate_record()
  # in the ActiveResource model for DrmaaTask on BrainPortal)
  def to_xml(options = {})
    options[:methods] ||= []
    options[:methods] << :type unless options[:methods].include?(:type)
    super options
  end

  # This is needed by the ActiveResource controller on
  # Bourreau to figure out which key of the update()
  # request contains the updated attributes (the key
  # vary with the class name, so DrmaaAbc is stored in
  # drmaa_abc)
  def uncamelize
    self.class.to_s.downcase.sub(/^drmaa_?/i,"drmaa_")
  end

  # All object destruction also implies termination!
  def before_destroy
    self.terminate
    self.removeDRMAAworkdir
  end

protected

  # Class constants
  @@DRMAA_session ||= DRMAA::Session.session_cache  # See comment at top of file

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
    DRMAA::STATE_UNDETERMINED          => "Does Not Exist",
    DRMAA::STATE_QUEUED_ACTIVE         => "Queued",
    DRMAA::STATE_SYSTEM_ON_HOLD        => "On Hold",
    DRMAA::STATE_USER_ON_HOLD          => "On Hold",
    DRMAA::STATE_USER_SYSTEM_ON_HOLD   => "On Hold",
    DRMAA::STATE_RUNNING               => "On CPU",
    DRMAA::STATE_SYSTEM_SUSPENDED      => "Suspended",
    DRMAA::STATE_USER_SUSPENDED        => "Suspended",
    DRMAA::STATE_USER_SYSTEM_SUSPENDED => "Suspended",
    DRMAA::STATE_DONE                  => "Does Not Exist",
    DRMAA::STATE_FAILED                => "Does Not Exist"
  }

  # Returns "On CPU", "Queued", "On Hold", "Suspended" or "Does Not Exist"
  # This set of states is NOT exactly the same as for status()
  # as a non-existing DRMAA job might mean a job not started,
  # a killed job or a job that's exited properly, and we can't tell
  # which is which based only on DRMAA::Session#job_ps()
  # See also the comments for @@DRMAA_States_To_Status
  def drmaa_status
    begin 
      state = @@DRMAA_session.job_ps(self.drmaa_jobid)
    rescue
      return "Does Not Exist"
    end
    status = @@DRMAA_States_To_Status[state] || "Does Not Exist"
    return status
  end

  # Expects that the WD has already been changed
  def run
    self.addlog("Launching Grid Engine job.")

    name     = self.class.to_s.gsub(/^Drmaa/i,"")
    commands = self.drmaa_commands  # Supplied by subclass; can use self.params

    # Create a bash command script out of the text
    # lines supplied by the subclass
    id = self.object_id.to_s.gsub(/\D/,"") || self.object_id.to_s
    qsubfile = ".qsub-#{id}.sh"
    io = File.open(qsubfile,"w")
# TODO use 'here' document
    io.write(
      "#!/bin/sh\n" +
      "\n" +
      "# Script created automatically by #{self.class.to_s} #{Revision_info}\n" +
      "\n" +
      commands.join("\n") +
      "\n" )
    io.close

     # Create the DRMAA job object
    job = CbrainDRMAAJob.new   # TODO see if we can use DRMAA::JobTemplate directly
    job.command = "/bin/bash"
    job.arg     = [ qsubfile ]
    job.stdout  = ":" + qsubfile + ".out"
    job.stderr  = ":" + qsubfile + ".err"
    job.join    = false
    job.wd      = self.drmaa_workdir
    job.name    = name

    # Queue the job and return true, at this point
    # it's not our 'job' to figure out if it worked
    # or not.
    self.drmaa_jobid = @@DRMAA_session.run(job)
    self.status      = "Queued"
    return true

  end

  def makeDRMAAworkdir
    name = self.class.to_s.gsub(/^Drmaa/,"")
    self.drmaa_workdir = (CBRAIN::DRMAA_sharedir + "/" + "#{name}-" + $$.to_s + self.object_id.to_s)
    self.addlog("Trying to create workdir '#{self.drmaa_workdir}'.")
    unless Dir.mkdir(self.drmaa_workdir,0700)
       raise "Cannot create directory #{self.drmaa_workdir}: $!"
    end
  end

  def removeDRMAAworkdir
    if self.drmaa_workdir
       self.addlog("Removing workdir '#{self.drmaa_workdir}'.")
       system("/bin/rm -rf \"#{self.drmaa_workdir}\" >/dev/null 2>/dev/null")
       self.drmaa_workdir = nil
    end
  end

end
