
#
# CBRAIN Project
#
# This is a replacement for the drmaa.rb library; this particular subclass
# of class Scir implements the PBS interface.
#
# Original author: Pierre Rioux
#
# $Id$
#

require 'scir'

class ScirPbsSession < Scir::Session

  Revision_info="$Id$"

  # Register ourselves as the real implementation for Scir::Session
  Scir.session_subclass = self.to_s

  def update_job_info_cache
    @job_info_cache = {}
    jid = 'Dummy'
    IO.popen("qstat -f #{CBRAIN::DEFAULT_QUEUE} 2>/dev/null","r") do |fh|
      fh.readlines.each do |line|
        if line =~ /^Job\s+id\s*:\s*(\S+)/i
          jid = Regexp.last_match[1]
          if jid =~ /^(\d+)/
            jid = Regexp.last_match[1]
          end
          next
        end
        next unless line =~ /^\s*job_state\s*=\s*(\S+)/i
        state = statestring_to_stateconst(Regexp.last_match[1])
        @job_info_cache[jid.to_s] = { :drmaa_state => state }
      end
    end
  end

  def statestring_to_stateconst(state)
    return Scir::STATE_RUNNING        if state.match(/R/i)
    return Scir::STATE_QUEUED_ACTIVE  if state.match(/Q/i)
    return Scir::STATE_USER_ON_HOLD   if state.match(/H/i)
    return Scir::STATE_USER_SUSPENDED if state.match(/S/i)
    return Scir::STATE_UNDETERMINED
  end

  def hold(jid)
    IO.popen("qhold #{shell_escape(jid)} 2>&1","r") do |i|
      p = i.readlines
      raise "Error holding: #{p.join("\n")}" if p.size > 0
      return
    end
  end

  def release(jid)
    IO.popen("qrls #{shell_escape(jid)} 2>&1","r") do |i|
      p = i.readlines
      raise "Error releasing: #{p.join("\n")}" if p.size > 0
      return
    end
  end

  def suspend(jid)
    raise "There is no 'suspend' action available for PBS clusters"
  end

  def resume(jid)
    raise "There is no 'resume' action available for PBS clusters"
  end

  def terminate(jid)
    IO.popen("qdel #{shell_escape(jid)} 2>&1","r") do |i|
      p = i.readlines
      raise "Error deleting: #{p.join("\n")}" if p.size > 0
      return
    end
  end

  def queue_tasks_tot_max
    queue = CBRAIN::DEFAULT_QUEUE
    queue = "default" if queue.blank?
    queueinfo = `qstat -Q #{shell_escape(queue)} | tail -1`
    # Queue              Max   Tot   Ena   Str   Que   Run   Hld   Wat   Trn   Ext T
    # ----------------   ---   ---   ---   ---   ---   ---   ---   ---   ---   --- -
    # brain               90    33   yes   yes     0    33     0     0     0     0 E
    fields = queueinfo.split(/\s+/)
    [ fields[2], fields[1] ]
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

class ScirPbsJobTemplate < Scir::JobTemplate

  # Register ourselves as the real implementation for Scir::JobTemplate
  Scir.jobtemplate_subclass = self.to_s

  def qsub_command
    raise "Error, this class only handle 'command' as /bin/bash and a single script in 'arg'" unless
      self.command == "/bin/bash" && self.arg.size == 1
    raise "Error: stdin not supported" if self.stdin

    command  = "qsub "
    command += "-S /bin/bash "                    # Always
    command += "-r n "                            # Always
    command += "-d #{shell_escape(self.wd)} "     if self.wd
    command += "-N #{shell_escape(self.name)} "   if self.name
    command += "-o #{shell_escape(self.stdout)} " if self.stdout
    command += "-e #{shell_escape(self.stderr)} " if self.stderr
    command += "-j oe "                           if self.join
    command += "-q #{shell_escape(self.queue)} "  if self.queue
    command += " #{CBRAIN::EXTRA_QSUB_ARGS} "     unless CBRAIN::EXTRA_QSUB_ARGS.empty?
    command += "#{shell_escape(self.arg[0])}"

    return command
  end

end
