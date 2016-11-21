
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

# This is a replacement for the drmaa.rb library; this particular subclass
# of class Scir implements a dummy cluster interface that still runs
# jobs locally as standard unix subprocesses.
#
# Original author: Pierre Rioux
class ScirUnix < Scir

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  class Session < Scir::Session #:nodoc:

    def update_job_info_cache #:nodoc:
      @job_info_cache = {}
      ps_command = case CBRAIN::System_Uname
        when /Linux/i
          "ps x -o pid,uid,state"
        when /Solaris/i
          "ps x -o pid,uid,state"  # not tested
        else
          "ps x -o pid,uid,state"  # not tested
      end
      psout, pserr = bash_this_and_capture_out_err(ps_command)
      raise "Cannot get output of '#{ps_command}' ?!?" if psout.blank? && ! pserr.blank?
      psout.split(/\s*\n\s*/).each do |line|
        next unless line =~ /\A\s*(\d+)\s+(\d+)\s+(\S+)/
        pid       = Regexp.last_match[1]
      # uid       = Regexp.last_match[2]
        statechar = Regexp.last_match[3]
        state     = statestring_to_stateconst(statechar)
        @job_info_cache[pid.to_s] = { :drmaa_state => state }
      end
      true
    end

    def statestring_to_stateconst(state) #:nodoc:
      return Scir::STATE_USER_SUSPENDED if state.match(/[t]/i)
      return Scir::STATE_RUNNING        if state.match(/[sruz]/i)
      return Scir::STATE_UNDETERMINED
    end

    def hold(jid) #:nodoc:
      true
    end

    def release(jid) #:nodoc:
      true
    end

    def suspend(jid) #:nodoc:
      Process.kill("-STOP",Process.getpgid(jid.to_i)) rescue true  # A negative signal name kills a GROUP
    end

    def resume(jid) #:nodoc:
      Process.kill("-CONT",Process.getpgid(jid.to_i)) rescue true  # A negative signal name kills a GROUP
    end

    def terminate(jid) #:nodoc:
      Process.kill("-TERM",Process.getpgid(jid.to_i)) rescue true  # A negative signal name kills a GROUP
    end

    def queue_tasks_tot_max #:nodoc:
      loadav = `uptime`.strip
      loadav.match(/averages?:\s*([\d\.]+)/i)
      loadtxt = Regexp.last_match[1] || "unknown"
      case CBRAIN::System_Uname
      when /Linux/i
        cpuinfo = `cat /proc/cpuinfo 2>&1`.split("\n")
        proclines = cpuinfo.select { |i| i.match(/\Aprocessor\s*:\s*/i) }
        return [ loadtxt , proclines.size.to_s ]
      when /Darwin/i
        hostinfo = `hostinfo 2>&1`.strip
        hostinfo.match(/\A(\d+) processors are/)
        numproc = Regexp.last_match[1] || "unknown"
        [ loadtxt, numproc ]
      else
        [ "unknown", "unknown" ]
      end
    rescue
      [ "exception", "exception" ]
    end

    def run(job) #:nodoc:
      reset_job_info_cache
      command = job.qsub_command
      pid = Process.fork do
        (3..50).each { |i| IO.for_fd(i).close rescue true } # with some luck, it's enough
        Process.setpgrp rescue true
        Kernel.exec("/bin/bash","-c",command)
        Process.exit!(0) # should never get here
      end
      Process.detach(pid)
      return pid.to_s
    end

    private

    def qsubout_to_jid(txt) #:nodoc:
      raise "Not used in this implementation."
    end

  end

  class JobTemplate < Scir::JobTemplate #:nodoc:

    # NOTE: We use a custom 'run' method in the Session, instead of Scir's version.
    def qsub_command #:nodoc:
      raise "Error, this class only handle 'command' as /bin/bash and a single script in 'arg'" unless
        self.command == "/bin/bash" && self.arg.size == 1
      raise "Error: stdin not supported" if self.stdin

      stdout = self.stdout || ":/dev/null"
      stderr = self.stderr || (self.join ? nil : ":/dev/null")

      stdout.sub!(/\A:/,"") if stdout
      stderr.sub!(/\A:/,"") if stderr

      command = ""
      command += "cd #{shell_escape(self.wd)} || exit 20;"  if self.wd
      command += "/bin/bash #{shell_escape(self.arg[0])}"
      command += "  > #{shell_escape(stdout)}"
      command += " 2> #{shell_escape(stderr)}"              if stderr
      command += " 2>&1"                                    if self.join && stderr.blank?

      return command
    end

  end

end

