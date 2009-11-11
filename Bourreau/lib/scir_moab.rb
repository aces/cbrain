
#
# CBRAIN Project
#
# This is a replacement for the drmaa.rb library; this particular subclass
# of class Scir implements the MOAB interface.
#
# Original author: Pierre Rioux
#
# $Id$
#

require 'scir'

class ScirMoabSession < Scir::Session

  Revision_info="$Id$"

  # Register ourselves as the real implementation for Scir::Session
  Scir.session_subclass = self.to_s

  def update_job_info_cache
    @job_info_cache = {}
    xmltext = ""
    IO.popen("showq --xml 2>/dev/null","r") do |fh|
      xmltext = fh.read
    end
    jobs = xmltext.split(/(<job\s.*?<\/job>)/i) # odd elements are our stuff
    1.step(jobs.size,2) do |i|
      jobxml = jobs[i]
      # <job AWDuration="3832" Class="single" DRMJID="165577.krylov.clumeq.mcgill.ca"
      #     EEDuration="1257185571" Group="aevans" JobID="165577" JobName="STDIN"
      #     MasterHost="cn050" PAL="krylov" ReqAWDuration="2592000" ReqProcs="1"
      #     RsvStartTime="1257185571" RunPriority="1" StartPriority="1" StartTime="1257185571"
      #     StatPSDed="3828.220000" StatPSUtl="3828.220000" State="Running" SubmissionTime="1257185571"
      #     SuspendDuration="0" User="prioux">
      # </job>
      jobid = 'Dummy'
      state = 'Running'
      if jobxml =~ /\bJobID="(\w+)"/i
         jobid = Regexp.last_match[1]
      end
      if jobxml =~ /\bState="(\S+?)"/i
         state = statestring_to_stateconst(Regexp.last_match[1])
      end
      @job_info_cache[jobid.to_s] = { :drmaa_state => state }
    end
    true
  end

  def statestring_to_stateconst(state)
    return Scir::STATE_RUNNING        if state.match(/Run|Starting/i)
    return Scir::STATE_QUEUED_ACTIVE  if state.match(/Idle|Queue|Defer|Staged/i)
    return Scir::STATE_USER_ON_HOLD   if state.match(/H[oe]ld/i)
    return Scir::STATE_USER_SUSPENDED if state.match(/Suspend/i)
    return Scir::STATE_UNDETERMINED
  end

  def hold(jid)
    IO.popen("mjobctl -h user #{shell_escape(jid)} 2>&1","r") do |i|
      p = i.read
      raise "Error holding: #{p.join("\n")}" unless p =~ /holds modified for job/i
      return
    end
  end

  def release(jid)
    IO.popen("mjobctl -u user #{shell_escape(jid)} 2>&1","r") do |i|
      p = i.read
      raise "Error releasing: #{p.join("\n")}" unless p =~ /holds modified for job/i
      return
    end
  end

  def suspend(jid)
    raise "There is no 'suspend' action available for MOAB clusters"
  end

  def resume(jid)
    raise "There is no 'resume' action available for MOAB clusters"
  end

  def terminate(jid)
    IO.popen("mjobctl -c #{shell_escape(jid)} 2>&1","r") do |i|
      p = i.read
      raise "Error deleting: #{p.join("\n")}" unless p =~ /job '\S+' cancelled/i
      return
    end
  end

  def queue_tasks_tot_max
    #queue = CBRAIN::DEFAULT_QUEUE
    #queue = "default" if queue.blank?
    #queueinfo = `qstat -Q #{shell_escape(queue)} | tail -1`
    # Queue              Max   Tot   Ena   Str   Que   Run   Hld   Wat   Trn   Ext T
    # ----------------   ---   ---   ---   ---   ---   ---   ---   ---   ---   --- -
    # brain               90    33   yes   yes     0    33     0     0     0     0 E
    #fields = queueinfo.split(/\s+/)
    [ "unknown", "unknown" ]
  rescue
    [ "exception", "exception" ]
  end

  private

  def qsubout_to_jid(txt)
    if txt && txt =~ /^(\d+)/
      return Regexp.last_match[1]
    end
    raise "Cannot find job ID from qsub output"
  end

end

class ScirMoabJobTemplate < Scir::JobTemplate

  # Register ourselves as the real implementation for Scir::JobTemplate
  Scir.jobtemplate_subclass = self.to_s

  def qsub_command
    raise "Error, this class only handle 'command' as /bin/bash and a single script in 'arg'" unless
      self.command == "/bin/bash" && self.arg.size == 1
    raise "Error: stdin not supported" if self.stdin

    command  = "msub "
    command += "-q #{shell_escape(self.queue)} "  if self.queue
    command += "-S /bin/bash "                    # Always
    command += "-r n "                            # Always
    command += "-d #{shell_escape(self.wd)} "     if self.wd
    command += "-N #{shell_escape(self.name)} "   if self.name
    command += "-o #{shell_escape(self.stdout)} " if self.stdout
    command += "-e #{shell_escape(self.stderr)} " if self.stderr
    command += "-j oe "                           if self.join
    command += " #{CBRAIN::EXTRA_QSUB_ARGS} "     unless CBRAIN::EXTRA_QSUB_ARGS.empty?
    command += "#{shell_escape(self.arg[0])}"

    return command
  end

end
