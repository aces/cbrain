
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

# Simple Cluster Interface in Ruby
# This is a replacement for the drmaa.rb library; it's more or less compatible
# but a lot less feature rich. It's also pure ruby. More specific cluster-dependent
# details are implemented in subclasses.
#
# Original author: Pierre Rioux
class Scir

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Returns the full revision info string as created by git
  # the value returned is for the current class or subclass.
  def self.revision_info
    self.const_get("Revision_info")
  end

  # These constants are the same as the ones used for DRMAA

  STATE_UNDETERMINED          = 0x00 #:nodoc:
  STATE_QUEUED_ACTIVE         = 0x10 #:nodoc:
  STATE_SYSTEM_ON_HOLD        = 0x11 #:nodoc:
  STATE_USER_ON_HOLD          = 0x12 #:nodoc:
  STATE_USER_SYSTEM_ON_HOLD   = 0x13 #:nodoc:
  STATE_RUNNING               = 0x20 #:nodoc:
  STATE_SYSTEM_SUSPENDED      = 0x21 #:nodoc:
  STATE_USER_SUSPENDED        = 0x22 #:nodoc:
  STATE_USER_SYSTEM_SUSPENDED = 0x23 #:nodoc:
  STATE_DONE                  = 0x30 #:nodoc:
  STATE_FAILED                = 0x40 #:nodoc:

  # Returns the file name for the implementation.
  def self.drmaa_implementation
    Scir.revision_info.basename
  end

  # Returns the revision number for the implementation.
  def self.version
    self.revision_info.short_commit
  end

  # Returns the class name for the implementation.
  def self.drm_system
    self.to_s
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
      :default_queue   => rr.cms_default_queue   || ""
    }
  end

  # Builds and return a session object for the implementation
  # +subclassname+ ; the object will be of class
  # subclassname::Session, as defined in +subclassname+.
  # A side effect of this is to record and cache permanently
  # the session object in a global Ruby variable, so only
  # one such session can be created, ever.
  def self.session_builder(subclassname,*args)
    subclass = Class.const_get(subclassname.to_s) rescue Object
    raise "Invalid subclass name #{subclassname}" unless subclass < self

    # Until I can find a way to keep this object persistent in Rails,
    # I'll have to keep storing it in a global.... sigh.

    #return @@session if self.class_variable_defined?('@@session')
    #@@session = subclass.const_get("Session").new(*args)
    #@@session

    # Implementation with global var.... hurgh.
    return $CBRAIN_SCIR_SESSION if $CBRAIN_SCIR_SESSION
    $CBRAIN_SCIR_SESSION = subclass.const_get("Session").new(*args)
    $CBRAIN_SCIR_SESSION
  end

  # Builds and return a job template object for the implementation
  # +subclassname+ ; the object will be of class
  # subclassname::JobTemplate, as defined in +subclassname+.
  def self.job_template_builder(subclassname,*args)
    subclass = Class.const_get(subclassname.to_s) rescue Object
    raise "Invalid subclass name #{subclass}" unless subclass < self
    job = subclass.const_get("JobTemplate").new_jobtemplate(*args)
    job
  end

  class Session #:nodoc:

    @@state_if_missing = Scir::STATE_UNDETERMINED

    public

    def revision_info #:nodoc:
      Class.const_get(self.class.to_s.sub(/::Session/,"")).revision_info
    end

    def initialize(job_ps_cache_delay = 30.seconds) #:nodoc:
      @job_ps_cache_delay = job_ps_cache_delay
      reset_job_info_cache
    end

    def run(job) #:nodoc:
      reset_job_info_cache
      command = job.qsub_command
      qsubout = ""
      IO.popen(command,"r") { |fh| qsubout = fh.read }
      return qsubout_to_jid(qsubout)
    end

    def update_job_info_cache #:nodoc:
      # sets @job_info_cache to a hash: { jid => drmaa_status, ... }
      raise "This method must be provided in a subclass."
    end

    def reset_job_info_cache #:nodoc:
      @job_info_cache     = nil
      @cache_last_updated = (100*@job_ps_cache_delay).seconds.ago
    end

    def job_ps(jid,caller_updated_at = nil) #:nodoc:
      caller_updated_at ||= (5*@job_ps_cache_delay).seconds.ago
      if ( @job_info_cache.nil?                                  ||
           @cache_last_updated < @job_ps_cache_delay.seconds.ago ||
           caller_updated_at   > @job_ps_cache_delay.seconds.ago
         )
        update_job_info_cache
        @cache_last_updated = Time.now
      end
      jinfo = @job_info_cache[jid.to_s]
      return jinfo[:drmaa_state] if jinfo
      return @@state_if_missing
    end

    def hold(jid) #:nodoc:
      raise "This method must be provided in a subclass"
    end

    def release(jid) #:nodoc:
      raise "This method must be provided in a subclass"
    end

    def suspend(jid) #:nodoc:
      raise "This method must be provided in a subclass"
    end

    def resume(jid) #:nodoc:
      raise "This method must be provided in a subclass"
    end

    def terminate(jid) #:nodoc:
      raise "This method must be provided in a subclass"
    end

    def queue_tasks_tot_max #:nodoc:
      [ "nyi", "nyi" ]
    end

    protected

    def qsubout_to_jid(i) #:nodoc:
      raise "Method qsubout_to_jid() must be provided in a subclass"
    end

    def shell_escape(s) #:nodoc:
      "'" + s.gsub(/'/,"'\\\\''") + "'"
    end

    def bash_this_and_capture_out_err(command) #:nodoc:
      tmpfile = "/tmp/capt.#{Process.pid}.#{Time.now.to_i}.#{rand(1000000)}"
      outfile = "#{tmpfile}.out"
      errfile = "#{tmpfile}.err"
      system("bash","-c","#{command} 0</dev/null 1>#{outfile} 2>#{errfile}")
      out = File.read(outfile) rescue nil
      err = File.read(errfile) rescue nil
      File.unlink(outfile)     rescue true
      File.unlink(errfile)     rescue true
      [ out, err ]
    end

  end

  class JobTemplate #:nodoc:

    # We only support a subset of DRMAA's job template
    attr_accessor :name, :command, :arg, :wd,
        :stdin, :stdout, :stderr, :join,
        :queue, :walltime, :memory,   # walltime is in seconds, memory in megabytes
        :tc_extra_qsub_args, :task_id

    def revision_info #:nodoc:
      Class.const_get(self.class.to_s.sub(/::JobTemplate/,"")).revision_info
    end

    def self.new_jobtemplate(params = {}) #:nodoc:
      job_template = self.new(params)
      job_template.queue = Scir.cbrain_config[:default_queue] if ( ! Scir.cbrain_config[:default_queue].blank? ) && ( job_template.queue.blank? )
      return job_template
    end

    def initialize(params = {}) #:nodoc:
      params.each_pair { |m,v| self.send("#{m}=",v) }
    end

    def qsub_command #:nodoc:
      raise "Method qsub_command() must be provided in a subclass."
    end

    protected

    def shell_escape(s) #:nodoc:
      "'" + s.gsub(/'/,"'\\\\''") + "'"
    end

  end

end

