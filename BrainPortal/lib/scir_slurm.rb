
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

# This particular subclass of class Scir implements the SLURM interface.
class ScirSlurm < Scir

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  class Session < Scir::Session #:nodoc:

    def update_job_info_cache #:nodoc:
      out_text, err_text = bash_this_and_capture_out_err(
        # the '%A' format returns the job ID
        # the '%t' format returns the status with the one or two letter codes.
        "squeue --format='%A %t' --noheader --user=#{CBRAIN::Rails_UserName.to_s.bash_escape}"
      )
      raise "Cannot get output of 'squeue'" if err_text.present?
      out_lines = out_text.split("\n")
      @job_info_cache = {}
      out_lines.each do |line|  # "12345 R"
        job_id, job_status = line.split(/\s+/)
        next unless job_id.present? && job_status.present?
        state = statestring_to_stateconst(job_status)
        @job_info_cache[job_id] = { :drmaa_state => state }
      end
      true
    end

    # From the 'squeue' man page:
    # BF  BOOT_FAIL       Job terminated due to launch failure, typically due to a hardware failure (e.g. unable to boot the node or block and the job can not be requeued).
    # CA  CANCELLED       Job was explicitly cancelled by the user or system administrator.  The job may or may not have been initiated.
    # CD  COMPLETED       Job has terminated all processes on all nodes with an exit code of zero.
    # CF  CONFIGURING     Job has been allocated resources, but are waiting for them to become ready for use (e.g. booting).
    # CG  COMPLETING      Job is in the process of completing. Some processes on some nodes may still be active.
    # F   FAILED          Job terminated with non-zero exit code or other failure condition.
    # NF  NODE_FAIL       Job terminated due to failure of one or more allocated nodes.
    # PD  PENDING         Job is awaiting resource allocation.
    # PR  PREEMPTED       Job terminated due to preemption.
    # R   RUNNING         Job currently has an allocation.
    # SE  SPECIAL_EXIT    The job was requeued in a special state. This state can be set by users, typically in EpilogSlurmctld, if the job has terminated with a particular exit value.
    # ST  STOPPED         Job has an allocation, but execution has been stopped with SIGSTOP signal.  CPUS have been retained by this job.
    # S   SUSPENDED       Job has an allocation, but execution has been suspended and CPUs have been released for other jobs.
    # TO  TIMEOUT         Job terminated upon reaching its time limit.
    def statestring_to_stateconst(state) #:nodoc:
      return Scir::STATE_RUNNING        if state == "R"  || state == "CG"
      return Scir::STATE_QUEUED_ACTIVE  if state == "PD" || state == "CF"
      #return Scir::STATE_USER_ON_HOLD   if ...
      return Scir::STATE_USER_SUSPENDED if state == "ST" || state == "S"
      return Scir::STATE_UNDETERMINED
    end

    def hold(jid) #:nodoc:
      raise "There is no 'hold' action available for SLURM clusters"
    end

    def release(jid) #:nodoc:
      raise "There is no 'release' action available for SLURM clusters"
    end

    def suspend(jid) #:nodoc:
      raise "There is no 'suspend' action available for SLURM clusters"
    end

    def resume(jid) #:nodoc:
      raise "There is no 'resume' action available for SLURM clusters"
    end

    def terminate(jid) #:nodoc:
      out = IO.popen("scancel #{shell_escape(jid)} 2>&1","r") { |i| i.read }
      raise "Error deleting: #{out.join("\n")}" if out.present?
      return
    end

    # Returns a structure similar to ClusterTask's extract_cpu_times_from_qsub_wrapper()
    # but obtained from the sacct command.
    #
    # Example sacct output for a job that used 2 minutes of user cpu,
    # 2 minutes of system cpu, and 2 minutes of sleep:
    #
    #       JobID  SystemCPU    UserCPU    CPUTime   TotalCPU CPUTimeRAW    Elapsed
    #------------ ---------- ---------- ---------- ---------- ---------- ----------
    #2904739       01:57.261  02:01.897   00:06:04  03:59.159        364   00:06:04
    #2904739.bat+  01:57.260  02:01.897   00:06:04  03:59.158        364   00:06:04
    #2904739.ext+   00:00:00   00:00:00   00:06:04   00:00:00        364   00:06:04
    def job_cpu_info(jid) #:nodoc:
      format = 'JobID,SystemCPU,UserCPU,Elapsed'
      out    = IO.popen("sacct -n -p -o #{format} -j #{shell_escape(jid.to_s)} 2>&1","r") { |i| i.read }
      rows   = out.split("\n").map { |line| line.split("|") } # output above is sep by pipes
      myrow  = rows.detect { |r| r[0].to_s == jid.to_s }
      return nil unless myrow

      syst_tot = slurm_time(myrow[1])
      user_tot = slurm_time(myrow[2])
      walltime = slurm_time(myrow[3])
      {
        :walltime => walltime,
        :user_loc => 0       , # cpu time of wrapper process only, not useful
        :syst_loc => 0       , # cpu time of wrapper process only, not useful
        :user_tot => user_tot, # cpu time of wrapper and subprocesses
        :syst_tot => syst_tot, # cpu time of wrapper and subprocesses
      }
    end

    # Converts '1-20:30:12.1' (or shorter versions)
    # into a number of seconds (float).
    def slurm_time(dhms) #:nodoc:
      comps   = dhms.split(/[:\-]/)
      seconds = comps.pop.to_f
      minutes = comps.pop.to_i
      hours   = comps.pop.to_i
      days    = comps.pop.to_i
      return seconds             +
             (60.0    * minutes) +
             (3600.0  * hours)   +
             (86400.0 * days)
    end

    def queue_tasks_tot_max #:nodoc:
      used="unk" ; max = "unk"
      out = IO.popen("sinfo --noheader -o '%X,%Y,%F'","r") { |i| i.read }
      # number of sockets per node, number of cores per socket, allocated/idle/other/total
      # e.g. 2+,16,915/77/51/1043
      if out =~ /(\d+)\D+(\d+)\D+(\d+)\/(\d+)\/(\d+)\/(\d+)/
        nsock  = Regexp.last_match[1].to_i
        ncores = Regexp.last_match[2].to_i
        alloc  = Regexp.last_match[3].to_i
        total  = Regexp.last_match[6].to_i
        used = nsock * ncores * alloc
        max  = nsock * ncores * total
      end
      [ used.to_s, max.to_s ]
    rescue
      [ "exception", "exception" ]
    end

    private

    def qsubout_to_jid(txt) #:nodoc:
      if txt.present? && txt =~ /Submitted.*job\s+(\d+)/i
        val = Regexp.last_match[1]
        return val unless val =~ /error/i
      end
      raise "Cannot find job ID from qsub output.\nOutput: #{txt}"
    end

  end

  class JobTemplate < Scir::JobTemplate #:nodoc:

    # Note: CBRAIN's 'queue' name is interpreted as SLURM's 'partition'.
    def qsub_command #:nodoc:
      raise "Error, this class only handle 'command' as /bin/bash and a single script in 'arg'" unless
        self.command == "/bin/bash" && self.arg.size == 1
      raise "Error: stdin not supported" if self.stdin

      command  = "sbatch "
      command += "-p #{shell_escape(self.queue)} "          if self.queue.present?
      command += "--no-requeue "
      command += "-D #{shell_escape(self.wd)} "             if self.wd.present?
      command += "--job-name=#{shell_escape(self.name)} "   if self.name.present?
      command += "--output=#{shell_escape(self.stdout.sub(/\A:/,""))} "   if self.stdout.present?
      command += "--error=#{shell_escape(self.stderr.sub(/\A:/,""))} "    if self.stderr.present?
      command += "#{Scir.cbrain_config[:extra_qsub_args]} " if Scir.cbrain_config[:extra_qsub_args].present?
      command += "--time=#{(self.walltime.to_i+60) / 60} "  if self.walltime.present?
      command += "--mem=#{self.memory}m "                   if self.memory.present?
      command += "-c #{self.ncores} "                       if self.ncores.present?
      command += "#{self.tc_extra_qsub_args} "              if self.tc_extra_qsub_args.present?
      command += "#{shell_escape(self.arg[0])} "
      command += " 2>&1"

      return command
    end

  end

end

