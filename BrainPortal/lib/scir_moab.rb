
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
# of class Scir implements the MOAB interface.
#
# Original author: Pierre Rioux
class ScirMoab < Scir

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  class Session < Scir::Session #:nodoc:

    def update_job_info_cache
      #xmltext, showqerr = bash_this_and_capture_out_err("showq --blocking --xml")
      xmltext, showqerr = bash_this_and_capture_out_err("showq --xml")
      xmltext.force_encoding('ASCII-8BIT') # THE STUPID MOAB XML DUMP CAN CONTAIN BINARY DATA!
      raise "Cannot get output of 'showq --blocking --xml' ?!?" if xmltext.blank? && ! showqerr.blank?
      raise "Cannot get XML from showq; got:\n---Start\n#{xmltext}\n---End\n" unless
        xmltext =~ /^\s*<Data>/i && xmltext =~ /<\/Data>\s*$/i
      @job_info_cache = {}
      if xmltext =~ /(<cluster.*?<\/cluster>)/
        @job_info_cache["!moab_cluster_info!"] = Regexp.last_match[1]
      end
      jobs = xmltext.split(/(<job\s[\S\s]*?<\/job>)/i) # odd elements are our stuff
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
        if jobxml =~ /\bJobID="(\S+?)"/i
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
      #IO.popen("mjobctl -c #{shell_escape(jid)} 2>&1","r") do |i|
      IO.popen("canceljob #{shell_escape(jid)} 2>&1","r") do |i|
        p = i.read
        raise "Error deleting: #{p.join("\n")}" unless p =~ /job '\S+' cancelled/i
        return
      end
    end

    def queue_tasks_tot_max
      job_ps("!dummy!") # trigger refresh if necessary
      moab_cluster_info = @job_info_cache["!moab_cluster_info!"]
      #<cluster LocalActiveNodes="43" LocalAllocProcs="270" LocalConfigNodes="49" LocalIdleNodes="4"
      #         LocalIdleProcs="26" LocalUpNodes="47" LocalUpProcs="296" RemoteActiveNodes="0" RemoteAllocProcs="0"
      #         RemoteConfigNodes="0" RemoteIdleNodes="0" RemoteIdleProcs="0" RemoteUpNodes="0" RemoteUpProcs="0"
      #         time="1263919636"></cluster>
      tot = max = "Unknown"
      if moab_cluster_info =~ /LocalAllocProcs="(\d+)"/
        tot = Regexp.last_match[1]
      end
      if moab_cluster_info =~ /LocalUpProcs="(\d+)"/
        max = Regexp.last_match[1]
      end
      [ tot, max ]
    rescue
      [ "exception", "exception" ]
    end

    private

    def qsubout_to_jid(txt)
      if txt && txt =~ /^(\S+)/
        val = Regexp.last_match[1]
        return val unless val =~ /error/i
      end
      raise "Cannot find job ID from qsub output.\nOutput: #{txt}"
    end

  end

  class JobTemplate < Scir::JobTemplate #:nodoc:

    def qsub_command
      raise "Error, this class only handle 'command' as /bin/bash and a single script in 'arg'" unless
        self.command == "/bin/bash" && self.arg.size == 1
      raise "Error: stdin not supported" if self.stdin

      command  = "msub "
      command += "-q #{shell_escape(self.queue)} "  unless self.queue.blank?
      command += "-S /bin/bash "                    # Always
      command += "-r n "                            # Always
      command += "-d #{shell_escape(self.wd)} "     if self.wd
      command += "-N #{shell_escape(self.name)} "   if self.name
      command += "-o #{shell_escape(self.stdout)} " if self.stdout
      command += "-e #{shell_escape(self.stderr)} " if self.stderr
      command += "-j oe "                           if self.join
      command += "#{Scir.cbrain_config[:extra_qsub_args]} " unless Scir.cbrain_config[:extra_qsub_args].blank?
      command += "#{self.tc_extra_qsub_args} "              unless self.tc_extra_qsub_args.blank?
      command += "-l walltime=#{self.walltime.to_i} "       unless self.walltime.blank?
      command += "#{shell_escape(self.arg[0])}"
      command += " 2>&1"

      return command
    end

  end

end

