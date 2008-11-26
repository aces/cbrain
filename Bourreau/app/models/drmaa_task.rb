
#
# CBRAIN Project
#
# DRMAA Job Wrapper Class
#
# Original author: Pierre Rioux
#
# $Id: blahblah.rb 43 2008-11-05 15:54:04Z prioux $
#

require 'drmaa'

class CbrainDRMAAJob < DRMAA::JobTemplate
end

class DRMAATask < ActiveRecord::Base

  Revision_info="$Id: blahblah.rb 43 2008-11-05 15:54:04Z prioux $"

  serialize :params

public

  def setup(params = {})
    true
  end

  def drmaa_commands(params = {})
    [ "true" ]
  end

  def save_results(params = {})
    true
  end




  def start_all
    self.makeDRMAAworkdir
    Dir.chdir(self.drmaa_workdir) do
      unless self.setup(params)
         self.addlog("Failed To Setup")
         self.status = "Failed To Setup"
         return self
      end
      unless self.run(params)
         self.addlog("Failed To Start")
         self.status = "Failed To Start"
         self.removeDRMAAworkdir
         return self
      end
    end
    self
  end

  def post_process(params = {})
    if self.status != "Data Ready"
      raise "post_process() called on a job that is not in Data Ready state"
    end
    Dir.chdir(self.drmaa_workdir) do
      saveok = self.save_results(params)
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
  # Some values are reached by calling some methods, such as
  # post_process()
  def status

    ar_status = super
    if ar_status.blank?
      raise "Unknown blank status obtained from Active Record"
    end

    # Final states that we can't get out of
    # except for "Data Ready" which can be moved to "Completed"
    # through the method call save_results()
    return ar_status if ar_status.match(/^(Failed|Data Ready|Terminated|Completed)$/)

    drmaastatus = self.drmaa_status

    # Steady states
    if drmaastatus.match(/^(On CPU|Suspended|On Hold|Queued)$/)
      ar_status = self.status = drmaastatus
      return ar_status
    end

    # At this point here then, drmaastatus == "Does Not Exist"
    if ar_status.match(/^(On CPU|Suspended|On Hold|Queued)$/)
      ar_status = self.status = "Data Ready"
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

  def addlog(message)
    message.sub(/\s*$/,"\n")
    log = self.log
    log = "" if log.blank?
    log += message
    self.log = log
  end

protected

# These are now active record attributes
#  @DRMAA_jobid    = nil        # -> self.drmaa_jobid
#  @DRMAA_workdir  = nil        # -> self.drmaa_workdir
#  @status         = nil        # -> self.status
#  @log            = []         # -> self.log

  @@DRMAA_session = DRMAA::Session.new
  @@DRMAA_States_To_Status = {
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
  def run(params = {})
    name = self.class.to_s.gsub(/^DRMAA_/,"")
    commands = self.drmaa_commands(params)
    id = @tag || self.object_id.to_s.gsub(/\D/,"") || self.object_id.to_s
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
    job = CbrainDRMAAJob.new
    job.command = "/bin/bash"
    job.arg     = [ qsubfile ]
    job.stdout  = ":" + qsubfile + ".out"
    job.stderr  = ":" + qsubfile + ".err"
    job.join    = false
    job.wd      = self.drmaa_workdir
    job.name    = name
    self.drmaa_jobid = @@DRMAA_session.run(job)
    self.status      = "Queued"
    return true
  end

  def makeDRMAAworkdir
    name = self.class.to_s.gsub(/^DRMAA_/,"")
    self.drmaa_workdir = (CBRAIN::DRMAA_sharedir + "/" + "#{name}-" + $$.to_s + self.object_id.to_s)
    unless Dir.mkdir(self.drmaa_workdir,0700)
       raise "Cannot create directory #{self.drmaa_workdir}: $!"
    end
  end

  def removeDRMAAworkdir
    if self.drmaa_workdir
       system("/bin/rm -rf \"#{self.drmaa_workdir}\"")
       self.drmaa_workdir = nil
    end
  end

end
