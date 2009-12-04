
#
# CBRAIN Project
#
# This is a replacement for the drmaa.rb library; this particular subclass
# of class Scir implements a dummy cluster interface that still runs
# jobs locally as standard unix subprocesses.
#
# Original author: Pierre Rioux
#
# $Id$
#

require 'scir'

class ScirLocalSession < Scir::Session

  Revision_info="$Id$"

  # Register ourselves as the real implementation for Scir::Session
  Scir.session_subclass = self.to_s

  def update_job_info_cache
    @job_info_cache = {}
    ps_command = case CBRAIN::System_Uname
      when /Linux/
        "ps -x -o pid,uid,state"
      when /Solaris/
        "ps -x -o pid,uid,state"  # not tested
      else
        "ps -x -o pid,uid,state"  # not tested
    end
    IO.popen(ps_command, "r") do |fh|
      fh.readlines.each do |line|
        next unless line =~ /^\s*(\d+)\s+(\d+)\s+(\S+)/
        pid       = Regexp.last_match[1]
        uid       = Regexp.last_match[2]  # not used
        statechar = Regexp.last_match[3]
        state     = statestring_to_stateconst(statechar)
        @job_info_cache[pid.to_s] = { :drmaa_state => state }
      end
    end
  end

  def statestring_to_stateconst(state)
    return Scir::STATE_USER_SUSPENDED if state.match(/[t]/i)
    return Scir::STATE_RUNNING        if state.match(/[sruz]/i)
    return Scir::STATE_UNDETERMINED
  end

  def hold(jid)
    true
  end

  def release(jid)
    true
  end

  def suspend(jid)
    Process.kill("STOP",jid.to_i) rescue true
  end

  def resume(jid)
    Process.kill("CONT",jid.to_i) rescue true
  end

  def terminate(jid)
    Process.kill("TERM",jid.to_i) rescue true
  end

  def queue_tasks_tot_max
    cpuinfo = `cat /proc/cpuinfo`.split("\n")
    proclines = cpuinfo.select { |i| i.match(/^processor\s*:\s*/i) }
    [ "unknown", proclines.size.to_s ]
  rescue
    [ "exception", "exception" ]
  end

  private

  def qsubout_to_jid(txt)
    if txt && txt =~ /^PID=(\d+)/
      return Regexp.last_match[1]
    end
    raise "Cannot find job ID from bash subshell output"
  end

end

class ScirLocalJobTemplate < Scir::JobTemplate

  # Register ourselves as the real implementation for Scir::JobTemplate
  Scir.jobtemplate_subclass = self.to_s

  def qsub_command
    raise "Error, this class only handle 'command' as /bin/bash and a single script in 'arg'" unless
      self.command == "/bin/bash" && self.arg.size == 1
    raise "Error: stdin not supported" if self.stdin

    stdout = self.stdout
    stderr = self.stderr

    stdout.sub!(/^:/,"") if stdout
    stderr.sub!(/^:/,"") if stderr

    command = ""
    command += "cd #{shell_escape(self.wd)} || exit 20; " if self.wd
    command += "/bin/bash #{shell_escape(self.arg[0])}"
    command += "  > #{shell_escape(stdout)} "             if stdout
    command += " 2> #{shell_escape(stderr)} "             if stderr
    command += " 2>&1 "                                   if self.join

    command = "bash -c \"echo PID=\\$\\$ ; #{command}\" | head -1 & "

    return command
  end

end
