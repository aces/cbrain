
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
      # on the implementation of bstat.  This method is supposed to
      # list all the statuses of the running tasks, and to keep it in
      # the @job_info_cache array.
      out, err = bash_this_and_capture_out_err("bjobs -a -noheader -u #{CBRAIN::Rails_UserName.to_s.bash_escape}")
      raise "Cannot get output of 'bjobs -a' ?!?" if out.blank? && ! err.blank?
      jid = 'Dummy'
      @job_info_cache = {}
      out.split(/\s*\n\s*/).each do |line|
        bjob_stat = line.gsub(/\s+/m, ' ').strip.split(" ")
        jid = bjob_stat[0]
        stat = bjob_stat[2]
        stat = statestring_to_stateconst(stat)	
        @job_info_cache[jid] = { :drmaa_state => stat } unless stat == Scir::STATE_DONE #Do not add tasks to job_info_cache if they are done so CBRAIN moves them to post-processing
      end
      true

    end

    def statestring_to_stateconst(state) #:nodoc:      
      # CBRAIN statuses to status strings parsed from the output of
      # bstat -f in method update_job_info_cache
      return Scir::STATE_RUNNING        if state.match(/RUN/i)
      return Scir::STATE_QUEUED_ACTIVE  if state.match(/PEND/i)
      return Scir::STATE_USER_SUSPENDED if state.match(/USUSP/i)
      return Scir::STATE_SYSTEM_SUSPENDED if state.match(/SSUSP/i)
      return Scir::STATE_DONE           if state.match(/DONE/i)
      return Scir::STATE_DONE           if state.match(/EXIT/i)
      return Scir::STATE_UNDETERMINED
    end

    def hold(jid) #:nodoc:
      raise "There is no 'hold' action available for LSF clusters"
    end

    def release(jid) #:nodoc:
      raise "There is no 'release' action available for LSF clusters"
    end

    def suspend(jid) #:nodoc:
      IO.popen("bstop #{shell_escape(jid)} 2>&1","r") do |i|
        p = i.readlines
        raise "Error suspending: #{p.join("\n")}" if p.size > 0
        return
      end
    end

    def resume(jid) #:nodoc:
      IO.popen("bresume #{shell_escape(jid)} 2>&1","r") do |i|
        p = i.readlines
        raise "Error resuming: #{p.join("\n")}" if p.size > 0
        return
      end
    end

    def terminate(jid) #:nodoc:
      # FIXME. Insert the command used in LSF to kill a job.
      IO.popen("bkill #{shell_escape(jid)} 2>&1","r") do |i|
        p = i.readlines
        raise "Error deleting: #{p.join("\n")}" if p.size > 0
        return
      end
    end

    private

    # FIXME: this is a util method used in update_job_info_cache. You
    # may want to remove it or to implement your own.
    def qsubout_to_jid(txt) #:nodoc:
      if txt && txt =~ /Job <(\d+)>/
        return Regexp.last_match[1]
      end
      raise "Cannot find job ID from qsub output.\nOutput: #{txt}"
    end

  end

  class JobTemplate < Scir::JobTemplate #:nodoc:

    # Modify this to pass the proper bsub arguments.
    def qsub_command #:nodoc:
      raise "Error, this class only handle 'command' as /bin/bash and a single script in 'arg'" unless
        self.command == "/bin/bash" && self.arg.size == 1
      raise "Error: stdin not supported" if self.stdin

      script = self.wd + '/' +self.arg[0]
      stdout = self.stdout.sub(':', '') if self.stdout
      stderr = self.stderr.sub(':', '') if self.stderr

      File.chmod(0755, script)

      command  = "bsub "      
      command += "-J #{shell_escape(self.name)} "   if self.name
      command += "-cwd #{shell_escape(self.wd)} "     if self.wd
      command += "-o #{shell_escape(stdout)} " if stdout
      command += "-e #{shell_escape(stderr)} " if stderr 
      command += "-q #{shell_escape(self.queue)} "  unless self.queue.blank?
      command += "#{Scir.cbrain_config[:extra_qsub_args]} " unless Scir.cbrain_config[:extra_qsub_args].blank?
      command += "#{self.tc_extra_qsub_args} "              unless self.tc_extra_qsub_args.blank?      
      command += "#{shell_escape(script)}"
      command += " 2>&1"

      return command
    end

  end

end

