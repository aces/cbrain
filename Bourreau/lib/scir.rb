
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

class Scir

  Revision_info="$Id$"

  # Returns the full revision info string as created by SVN;
  # the value returned is for the current class or subclass.
  def self.revision_info
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

  # Returns the file name for the implementation.
  def self.drmaa_implementation
    Scir.revision_info.svn_id_file
  end

  # Returns the revision number for the implementation.
  def self.version
    self.revision_info.svn_id_rev
  end

  # Returns the class name for the implementation.
  def self.drm_system
    self.class.to_s
  end

  # This method acts as a interface between Scir and
  # the CBRAIN subsystem, extracting the values for
  # the qsub extra args or default queue from the
  # Rail's RemoteResource object.
  def self.cbrain_config
    return @config if @config
    rr = RemoteResource.current_resource
    @config = {
      :extra_qsub_args => rr.cms_extra_qsub_args || "",
      :default_queue   => rr.cms_default_queue   || "",
    }
  end

  # Builds and return a session object for the implementation
  # +subclassname+ ; the object will be of class
  # subclassname::Session, as defined in +subclassname+.
  # A side effect of this is to record and cache permenantly
  # the session object in a global Ruby variable, so only
  # one such session can be created, ever.
  def self.session_builder(subclassname,*args)
    subclass = Class.const_get(subclassname.to_s) rescue Object
    raise "Invalid subclass name #{subclassname}" unless subclass < self
    # Until I can find a way to keep this object persistent in Rails,
    # I'll have to keep storing it in a global.... sigh.
    #return @@session if self.class_variable_defined?('@@session')
    #@@session = subclass.const_get("Session").new(*args)
    return $CBRAIN_SCIR_SESSION if $CBRAIN_SCIR_SESSION
    $CBRAIN_SCIR_SESSION = subclass.const_get("Session").new(*args)
#puts "\e[1;37;42mCREATED SCIR SESSION for #{subclass} in #{self.class}=#{self.object_id} as #{@@session.class}=#{@@session.object_id}\e[0m"
puts "\e[1;37;42mCREATED SCIR SESSION for #{subclass} in #{self.class}=#{self.object_id} as #{$CBRAIN_SCIR_SESSION.class}=#{$CBRAIN_SCIR_SESSION.object_id}\e[0m"
    #@@session
    $CBRAIN_SCIR_SESSION
  end

  # Builds and return a job template object for the implementation
  # +subclassname+ ; the object will be of class
  # subclassname::JobTemplate, as defined in +subclassname+.
  def self.job_template_builder(subclassname,*args)
    subclass = Class.const_get(subclassname.to_s) rescue Object
    raise "Invalid subclass name #{subclass}" unless subclass < Scir::JobTemplate
    job = subclass.const_get("JobTemplate").new(*args)
    job
  end

  class Session

    public

    def revision_info #:nodoc:
      Class.const_get(self.class.to_s.sub(/::Session/,"")).revision_info
    end

    def initialize(job_ps_cache_delay = 30.seconds) #:nodoc:
      @job_ps_cache_delay = job_ps_cache_delay
      reset_job_info_cache
    end

    def run(job)
      reset_job_info_cache
      command = job.qsub_command
      qsubout = ""
      IO.popen(command,"r") { |fh| qsubout = fh.read }
      return qsubout_to_jid(qsubout)
    end

    def update_job_info_cache
      # sets @job_info_cache to a hash: { jid => drmaa_status, ... }
      raise "This method must be provided in a subclass."
    end

    def reset_job_info_cache
      @job_info_cache     = nil
      @cache_last_updated = (100*@job_ps_cache_delay).seconds.ago
    end

    def job_ps(jid,caller_updated_at = nil)
      caller_updated_at ||= (5*@job_ps_cache_delay).seconds.ago
      if @job_info_cache.nil? || @cache_last_updated < @job_ps_cache_delay.ago || caller_updated_at > @job_ps_cache_delay.ago
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

    def revision_info #:nodoc:
      Class.const_get(self.class.to_s.sub(/::JobTemplate/,"")).revision_info
    end

    def self.new_jobtemplate(params = {})
      subclassname = Scir.jobtemplate_subclass
      subclass     = Class.const_get(subclassname)
      returning subclass.new(params) do |job|
        job.queue = Scir.cbrain_config[:default_queue] if ( ! Scir.cbrain_config[:default_queue].blank? ) && ( job.queue.blank? )
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
