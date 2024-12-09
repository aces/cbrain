
#
# CBRAIN Project
#
# Copyright (C) 2008-2024
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
class ScirGcloudBatch < Scir

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  class Session < Scir::Session #:nodoc:

    def update_job_info_cache #:nodoc:
      out_text, err_text = bash_this_and_capture_out_err(
        # the '%A' format returns the job ID
        # the '%t' format returns the status with the one or two letter codes.
        "gcloud batch jobs list #{gcloud_location()}"
      )
      raise "Cannot get output of 'squeue'" if err_text.present?
      out_lines = out_text.split("\n")
      @job_info_cache = {}
      #NAME                                                                                LOCATION                 STATE
      #projects/tidal-reactor-438920-g4/locations/northamerica-northeast1/jobs/transcode   northamerica-northeast1  FAILED
      #projects/tidal-reactor-438920-g4/locations/northamerica-northeast1/jobs/test3       northamerica-northeast1  SUCCEEDED
      #projects/tidal-reactor-438920-g4/locations/northamerica-northeast1/jobs/tr1         northamerica-northeast1  FAILED
      # In a real deploy, all jobs IDs will be 'cbrain-{task.id}-{task.run_number}'
      out_lines.each do |line|
        job_path, job_location, job_status = line.split(/\s+/)
        next unless job_path.present? && job_status.present?
        job_id = Pathname.new(job_path).basename
        state = statestring_to_stateconst(job_status)
        @job_info_cache[job_id] = { :drmaa_state => state }
      end
      true
    end

    def statestring_to_stateconst(state) #:nodoc:
      return Scir::STATE_RUNNING        if state =~ /RUNNING/i
      return Scir::STATE_QUEUED_ACTIVE  if state =~ /SCHEDULED/i
      return Scir::STATE_DONE           if state =~ /COMPLETED/i
      return Scir::STATE_FAILED         if state =~ /FAILED/i
      return Scir::STATE_UNDETERMINED
    end

    def hold(jid) #:nodoc:
      raise "There is no 'hold' action available for GCLOUD clusters"
    end

    def release(jid) #:nodoc:
      raise "There is no 'release' action available for GCLOUD clusters"
    end

    def suspend(jid) #:nodoc:
      raise "There is no 'suspend' action available for GCLOUD clusters"
    end

    def resume(jid) #:nodoc:
      raise "There is no 'resume' action available for GCLOUD clusters"
    end

    def terminate(jid) #:nodoc:
      out = IO.popen("gcloud batch jobs delete #{gcloud_location()} #{shell_escape(jid)} 2>&1","r") { |i| i.read }
      #raise "Error deleting: #{out.join("\n")}" if whatever  TODO
      return
    end

    def gcloud_location
      #TODO better
      "--location northamerica-northeast1"
    end

    def queue_tasks_tot_max #:nodoc:
      # Not Yet Implemented
      [ "unknown", "unknown" ]
    end

    private

    def qsubout_to_jid(txt) #:nodoc:
      struct = YAML.load(txt)
      fullname = struct['name'] # "projects/tidal-reactor-438920-g4/locations/northamerica-northeast1/jobs/cbrain-123-1-092332"
      Pathname.new(fullname).basename # cbrain-123-1-092332
    rescue => ex
      raise "Cannot find job ID from 'gcloud batch jobs submit' output. Text was blank" if txt.blank?
      File.open("/tmp/debug.submit_error.txt","a") { |fh| fh.write("\n----\n#{txt}") }
      raise "Cannot find job ID from 'gcloud batch jobs submit' output."
    end

  end

  class JobTemplate < Scir::JobTemplate #:nodoc:

    def bucket_name
      "bianca-9945788255514"
    end

    def bucket_mount_point
      "/mnt/cbrain"
    end

    def gcloud_location
      #TODO better
      "--location northamerica-northeast1"
    end

    def qsub_command #:nodoc:
      raise "Error, this class only handle 'command' as /bin/bash and a single script in 'arg'" unless
        self.command == "/bin/bash" && self.arg.size == 1
      raise "Error: stdin not supported" if self.stdin
      raise "Error: name is required"    if self.name.blank?
      raise "Error: name must be made of alphanums and dashes" if self.name !~ /\A[a-zA-Z][\w\-]*\w\z/

      # The name is the job ID, so we need a distinct suffix even for the same task
      name = name[0..50] if name.size > 50
      name = name + DateTime.now.strftime("-%H%M%S") # this should be good enough

      command  = "gcloud batch jobs submit #{self.name.downcase} #{gcloud_location} "
      command += "#{self.tc_extra_qsub_args} "              if self.tc_extra_qsub_args.present?
      command += "#{Scir.cbrain_config[:extra_qsub_args]} " if Scir.cbrain_config[:extra_qsub_args].present?

      script_name = self.arg[0]
      script_command  = ""
      script_command += "cd #{shell_escape(self.wd)} && " if self.wd.present?
      script_command += "bash #{shell_escape(script_name)} "
      script_command += "1> #{shell_escape(self.stdout.sub(/\A:/,""))} " if self.stdout.present?
      script_command += "2> #{shell_escape(self.stderr.sub(/\A:/,""))} " if self.stderr.present?

      walltime = self.walltime.presence || 600 # seconds
      memory   = self.memory.presence   || 2000 # mb

      json_config_text = json_cloud_batch_jobs_config(
        script_command,
        memory,
        bucket_name(),
        bucket_mount_point(),
        walltime,
      )

      # Write the json config to a file; use a name unique enough for the current submission,
      # bu we can crush at a later date too. Maybe use job name?!?
      pid_threadid         = "#{Process.pid}-#{Thread.current.object_id}"
      json_tmp_config_file = "/tmp/job_submit-#{pid_threadid}.json"
      File.open(json_tmp_config_file,"w") { |fh| fh.write json_config_text }

      command += "--config #{json_tmp_config_file} 2>/dev/null" # we must ignore the friendly message line in stderr

      return command
    end

    def json_cloud_batch_jobs_config(command, maxmem_mb, bucket_name, mount_point, walltime_s)
      struct = struct_gcloud_batch_jobs_config_template.dup
      task_spec = struct["taskGroups"][0]["taskSpec"]
      task_spec["runnables"][0]["script"]["text"]  = command
      task_spec["computeResource"]["cpuMilli"]     = 2000 # 1000 per core
      task_spec["computeResource"]["memoryMib"]    = maxmem_mb
      task_spec["volumes"][0]["gcs"]["remotePath"] = bucket_name
      task_spec["volumes"][0]["mountPath"]         = mount_point
      task_spec["maxRunDuration"]                  = "#{walltime_s}s"
      struct.to_json
    end

    def struct_gcloud_batch_jobs_config_template
      {
        "taskGroups" => [
          {
            "taskSpec" => {
              "runnables" => [
                {
                  "script" => {
                    "text" => "COMMAND_ON_NODE_HERE",
                  }
                }
              ],
              "computeResource" => {
                "cpuMilli"  => 2000,
                "memoryMib" => 2048,
              },
              "volumes" => [
                {
                  "gcs" => {
                    "remotePath" => "BUCKET_NAME_HERE",
                  },
                  "mountPath" => "BUCKET_MOUNT_PATH_HERE",
                }
              ],
              "maxRetryCount"  => 1,
              "maxRunDuration" => "WALLTIME_HERE",
            },
            "taskCount"   => 1,
            "parallelism" => 1
          }
        ],
        "allocationPolicy" => {
          "instances" => [
            {
              "policy" => {
                "machineType"       => "n2d-standard-4",
                "provisioningModel" => "SPOT",
              }
            }
          ]
        },
        "logsPolicy" => {
          "destination" => "CLOUD_LOGGING",
        }
      }.freeze
    end

  end # class JobTemplate

end # class ScirGcloudBatch
