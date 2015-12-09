
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

# This subclass of class Scir implements the LSF interface.
#
class ScirLsf < Scir

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  class Session < Scir::Session #:nodoc:

    def update_job_info_cache #:nodoc:
      # FIXME: modify this method based
      # on the implementation of bstat.  This method is supposed to
      # list all the statuses of the running tasks, and to keep it in
      # the @job_info_cache array.
      out, err = bash_this_and_capture_out_err("bstat -f -u #{CBRAIN::Rails_UserName.to_s.bash_escape}")
      raise "Cannot get output of 'bstat -f' ?!?" if out.blank? && ! err.blank?
      jid = 'Dummy'
      @job_info_cache = {}
      out.split(/\s*\n\s*/).each do |line|
        line.force_encoding('ASCII-8BIT')  # some pbs 'qstat' commands output junk binary data!
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
      true
    end

    def statestring_to_stateconst(state) #:nodoc:
      # FIXME. Assign proper
      # CBRAIN statuses to status strings parsed from the output of
      # bstat -f in method update_job_info_cache
      return Scir::STATE_RUNNING        if state.match(/R/i)
      return Scir::STATE_QUEUED_ACTIVE  if state.match(/Q/i)
      return Scir::STATE_USER_ON_HOLD   if state.match(/H/i)
      return Scir::STATE_USER_SUSPENDED if state.match(/S/i)
      return Scir::STATE_UNDETERMINED
    end

    def hold(jid) #:nodoc:
      # FIXME. If LSF supports holding jobs, insert the right command here.
      # Otherwise, just raise an exception. 
      IO.popen("qhold #{shell_escape(jid)} 2>&1","r") do |i|
        p = i.readlines
        raise "Error holding: #{p.join("\n")}" if p.size > 0
        return
      end
    end

    def release(jid) #:nodoc:
      # FIXME. If LSF supports releasing jobs, insert the right command here.
      # Otherwise, just raise an exception. 
      IO.popen("qrls #{shell_escape(jid)} 2>&1","r") do |i|
        p = i.readlines
        raise "Error releasing: #{p.join("\n")}" if p.size > 0
        return
      end
    end

    def suspend(jid) #:nodoc:
      raise "There is no 'suspend' action available for LSF clusters"
    end

    def resume(jid) #:nodoc:
      raise "There is no 'resume' action available for LSF clusters"
    end

    def terminate(jid) #:nodoc:
      # FIXME. Insert the command used in LSF to kill a job.
      IO.popen("bdel #{shell_escape(jid)} 2>&1","r") do |i|
        p = i.readlines
        raise "Error deleting: #{p.join("\n")}" if p.size > 0
        return
      end
    end

    private

    # FIXME: this is a util method used in update_job_info_cache. You
    # may want to remove it or to implement your own.
    def qsubout_to_jid(txt) #:nodoc:
      if txt && txt =~ /^(\d+)/
        return Regexp.last_match[1]
      end
      raise "Cannot find job ID from qsub output.\nOutput: #{txt}"
    end

  end

  class JobTemplate < Scir::JobTemplate #:nodoc:

    # FIXME: modify this to pass the proper bsub arguments.
    def qsub_command #:nodoc:
      raise "Error, this class only handle 'command' as /bin/bash and a single script in 'arg'" unless
        self.command == "/bin/bash" && self.arg.size == 1
      raise "Error: stdin not supported" if self.stdin

      command  = "bsub "
      command += "-S /bin/bash "                    # Always
      command += "-r n "                            # Always
      command += "-d #{shell_escape(self.wd)} "     if self.wd 
      command += "-N #{shell_escape(self.name)} "   if self.name
      command += "-o #{shell_escape(self.stdout)} " if self.stdout
      command += "-e #{shell_escape(self.stderr)} " if self.stderr
      command += "-j oe "                           if self.join
      command += "-q #{shell_escape(self.queue)} "  unless self.queue.blank?
      command += "#{Scir.cbrain_config[:extra_qsub_args]} " unless Scir.cbrain_config[:extra_qsub_args].blank?
      command += "#{self.tc_extra_qsub_args} "              unless self.tc_extra_qsub_args.blank?
      command += "-l walltime=#{self.walltime.to_i} "       unless self.walltime.blank?
      command += "#{shell_escape(self.arg[0])}"
      command += " 2>&1"

      return command
    end

  end

end

