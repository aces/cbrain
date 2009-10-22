
#
# CBRAIN Project
#
# This is a replacement for the drmaa.rb library; it's more or less compatible
# but a lot less feature rich. It's also pure ruby. More specific cluster-dependent
# details are implemented in subclasses.
#
# Original author: Pierre Rioux
#
# $Id$
#

module Scir

  Revision_info="$Id$"

  def Scir.revision_info
    self.const_get("Revision_info")
  end

  # These constants are the same as the ones used for DRMAA
  STATE_UNDETERMINED          = 0x00
  STATE_QUEUED_ACTIVE         = 0x10
  STATE_SYSTEM_ON_HOLD        = 0x11
  STATE_USER_ON_HOLD          = 0x12
  STATE_USER_SYSTEM_ON_HOLD   = 0x13
  STATE_RUNNING               = 0x20
  STATE_SYSTEM_SUSPENDED      = 0x21
  STATE_USER_SUSPENDED        = 0x22
  STATE_USER_SYSTEM_SUSPENDED = 0x23
  STATE_DONE                  = 0x30
  STATE_FAILED                = 0x40

  def Scir.drmaa_implementation
    Scir.revision_info.svn_id_file
  end

  def Scir.version
    Scir.revision_info.svn_id_rev
  end

  def Scir.drm_system
    Scir.session_subclass
  end

  def Scir.session_subclass=(subclassname)
    @@Session_subclass = subclassname
  end

  def Scir.session_subclass
    @@Session_subclass
  end

  def Scir.jobtemplate_subclass=(subclassname)
    @@Jobtemplate_subclass = subclassname
  end

  def Scir.jobtemplate_subclass
    @@Jobtemplate_subclass
  end

class Session

  Revision_info="$Id$"

public

  # Opens a session once, then cache it
  def Session.session_cache #:nodoc:
    @@session_cache = self.new_session unless self.class_variable_defined?('@@session_cache')
    @@session_cache
  end

  def self.new_session(job_ps_cache_delay = 60.seconds)
    subclassname = Scir.session_subclass
    subclass     = Class.const_get(subclassname)
    return subclass.new(job_ps_cache_delay)
  end

  def initialize(job_ps_cache_delay = 60.seconds)
    @job_ps_cache_delay = job_ps_cache_delay
    @job_info_cache     = {}   # jid => { :drmaa_state => drmaa_state_const, ... }
    @cache_last_updated = (2*job_ps_cache_delay).seconds.ago
  end

  def run(job)
    command = job.qsub_command
    IO.popen(command,"r") do |i|
      return qsubout_to_jid(i)
    end
    @cache_last_updated = (2*job_ps_cache_delay).seconds.ago # invalidates @job_info_cache
  end

  def update_job_info_cache
    true
  end

  def job_ps(jid)
    if @cache_last_updated < @job_ps_cache_delay.ago
      update_job_info_cache
      @cache_last_updated = Time.now
    end
    jinfo = @job_info_cache[jid.to_s]
    return jinfo[:drmaa_state] if jinfo
    Scir::STATE_UNDETERMINED
  end

  def hold(jid)
    raise "This method must be provided in a subclass"
  end

  def release(jid)
    raise "This method must be provided in a subclass"
  end

  def suspend(jid)
    raise "This method must be provided in a subclass"
  end

  def resume(jid)
    raise "This method must be provided in a subclass"
  end

  def terminate(jid)
    raise "This method must be provided in a subclass"
  end

  def queue_tasks_tot_max
    [ "nyi", "nyi" ]
  end

  protected

  def qsubout_to_jid(i)
    raise "Method qsubout_to_jid() must be provided in a subclass"
  end

  def shell_escape(s)
    "'" + s.gsub(/'/,"'\\\\''") + "'"
  end

end

class JobTemplate

  # We only support a subset of DRMAA's job template
  attr_accessor :name, :command, :arg, :wd, :stdin, :stdout, :stderr, :join, :queue

  def self.new_jobtemplate(params = {})
    subclassname = Scir.jobtemplate_subclass
    subclass     = Class.const_get(subclassname)
    returning subclass.new(params) do |job|
      job.queue = CBRAIN::DEFAULT_QUEUE if ( ! CBRAIN::DEFAULT_QUEUE.blank? ) && ( job.queue.blank? )
    end
  end

  def initialize(params = {})
    params.each_pair { |m,v| self.send("#{m}=",v) }
  end

  def qsub_command
    raise "Method qsub_command() must be provided in a subclass."
  end

  protected

  def shell_escape(s)
    "'" + s.gsub(/'/,"'\\\\''") + "'"
  end

end

end
