
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


# An abstract Scir class to access clouds.
class ScirCloud < Scir

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # An abstract method that returns an array containing instance types
  # available on this cloud, for instance:
  #     ["m1.small", "m2.large"]
  def self.get_available_instance_types(bourreau)
    raise "Needs to be implemented in a sub-class"
  end

  # An abstract method that returns an array containing arrays of size
  # 2 with the ids and names of disk images available to the bourreau,
  # for instance:
  #     [ ["CentOS7","ami-12345"], ["CentOS6","ami-6789"] ]
  # This (weird) data structure is used to pass the result of this method in a Rails select tag.
  def self.get_available_disk_images(bourreau)
    raise "Needs to be implemented in a sub-class"
  end

  # An abstract method that returns an array containing arrays of size
  # 1 with the ids the key pairs available to the bourreau,
  # for instance:
  #     [ ["id_rsa_cbrain_portal"], ["personal_key"] ]
  # This (weird) data structure is used to pass the result of this method in a Rails select tag.
  def self.get_available_key_pairs(bourreau)
    raise "Needs to be implemented in a sub-class"
  end

  # Returns true of task is a VM
  def self.is_vm_task?(task)
    return task.is_a?(CbrainTask::StartVM)
  end

  class Session < Scir::Session

    # Returns the local IP of the (VM) task in the cloud.
    def get_local_ip(jid)
      raise "Needs to be provided in a sub-class"
    end

    def hold_vm(jid)
      raise "Needs to be implemented in a sub-class"
    end

    def release_vm(jid)
      raise "Needs to be implemented in a sub-class"
    end

    def suspend_vm(jid)
      raise "Needs to be implemented in a sub-class"
    end

    def resume(jid)
      raise "Needs to be implemented in a sub-class"
    end

    # Terminates the VM.
    def terminate_vm(jid)
      raise "Needs to be implemented in a sub-class"
    end

    # Submits a VM to the cloud.
    # Parameters:
    # * vm_name: name of the VM to create, e.g "CBRAIN worker".
    # * image_id: image id used by the VM. Specific to the cloud
    #             backend. Example: "ami-03cc9133".
    # * key_name: ssh key name that will be authorized in the VM.
    #             The corresponding key pair has to be configured
    #             in the cloud. Usually, the key name corresponds
    #             to the ssh portal key of the CBRAIN portal.
    #             Example: "id_cbrain_portal_scir_amazon".
    # * instance_type: instance type used by the VM. Example:
    #                  "t2_small".
    # * tag_value: a string used to tag the VM in the cloud.
    def submit_vm(vm_name,image_id,key_name,instance_type,tag_value)
      raise "Needs to be implemented in a sub-class"
    end

    # All the subsequent methods handle two types of tasks: (1) VM
    # tasks, identified using ScirCloud.is_vm_task?, and regular tasks
    # that run inside VMs.

    def hold(jid)
      cbrain_task = CbrainTask.where(:cluster_jobid => jid).first
      if ScirCloud.is_vm_task?(cbrain_task)
          hold_vm(cbrain_task.cluster_jobid)
      else
        true # as in scir_unix
      end
    end

    def release(jid)
      cbrain_task = CbrainTask.where(:cluster_jobid => jid).first
      if ScirCloud.is_vm_task?(cbrain_task)
        release_vm(cbrain_task.cluster_jobid)
      else
        true # as in scir_unix
      end
    end

    def suspend(jid)
      cbrain_task = CbrainTask.where(:cluster_jobid => jid).first
      if ScirCloud.is_vm_task?(cbrain_task)
        suspend_vm(cbrain_task.cluster_jobid)
      else
        pid = get_pid(jid)
        command = "kill -STOP #{pid}"
        begin
          vm_task.run_command_in_vm(command)
        rescue => ex
          # if the VM executing this task cannot be reached,
          # then the task should be put in status terminated. Otherwise, if VM
          # shuts down and the task is still in there, it will never be
          # terminated.
          raise ex unless ex.message.include? "Cannot establish connection with VM"
        end
      end
    end

    def resume(jid)
      cbrain_task = CbrainTask.where(:cluster_jobid => jid).first
      if ScirCloud.is_vm_task?(cbrain_task)
        resume_vm(cbrain_task.cluster_jobid)
      else
        pid = get_pid(jid)
        command = "kill -CONT #{pid}"
        begin
          vm_task.run_command_in_vm(command)
        rescue => ex
          raise ex unless ex.message.include? "Cannot establish connection with VM"
          #if the VM executing this task cannot be reached, then the task should
          #be put in status terminated. Otherwise, if VM shuts down and the task
          #is still in there, it could never be terminated.
        end
      end
    end

    # Terminates the VM.
    def terminate(jid)
      cbrain_task = CbrainTask.where(:cluster_jobid => jid).first
      if ScirCloud.is_vm_task?(cbrain_task)
        # Terminates all the tasks that may be running in the VM
        TaskVmAllocation.where(:vm_id => cbrain_task.id).all.each { |alloc|
          CbrainTask.find(alloc.task_id).terminate
        }
        # Terminates the VM
        terminate_vm(cbrain_task.cluster_jobid)
      else
        pid = get_pid(jid)
        command = "kill -TERM #{pid}"
        begin
          vm_task.run_command_in_vm(command)
        rescue => ex
          raise ex unless ex.message.include? "Cannot establish connection with VM"
          #if the VM executing this task cannot be reached, then the task should
          #be put in status terminated. Otherwise, if VM shuts down and the task
          #is still in there, it could never be terminated.
        end
      end
    end

    # Overrides the 'job_ps' method of class Scir.
    def job_ps(jid,caller_updated_at = nil) #:nodoc:
      cbrain_task = CbrainTask.where(:cluster_jobid => jid).first

      # VM tasks can be monitored with the regular cache mechanism
      # implemented in Scir (update_job_info_cache is of course
      # overriden in the children classes of ScirCloud).
      return super if ScirCloud.is_vm_task?(cbrain_task)

      # Monitoring of tasks running in VMs
      pid = get_pid(jid)
      vm_id = get_vm_id(jid)
      vm_task = CbrainTask.find(vm_id)
      # The following statement raises an exception if directories
      # cannot be mounted. It is not costly due to the caching
      # mechanism implemented in StartVM.is_mounted?
      vm_task.mount_directories
      command = "ps -p #{pid} -o pid,state | awk '$1 == \"#{pid}\" {print $2}'"
      status_letter = vm_task.run_command_in_vm(command).gsub("\n","")
      return Scir::STATE_DONE if status_letter == ""
      return Scir::STATE_RUNNING if status_letter.match(/[srzu]/i)
      return Scir::STATE_USER_SUSPENDED if status_letter.match(/[t]/i)
      return Scir::STATE_UNDETERMINED
    end

    # Overrides the 'run' method of class Scir.
    def run(job)
      cbrain_task = CbrainTask.find(job.task_id)
      # The task is a VM, it must be submitted to the cloud
      if ScirCloud.is_vm_task?(cbrain_task)
        vm = submit_vm("CBRAIN Worker", cbrain_task.params[:disk_image], cbrain_task.params[:ssh_key_pair],cbrain_task.params[:instance_type], cbrain_task.params[:tag])
        return vm.instance_id.to_s
      end
      # The task needs to be executed in a VM
      vm_id = schedule_task_on_vm(cbrain_task)
      vm_task = CbrainTask.find(vm_id)
      raise "VM task #{vm_task.id} is not a VM task (it is a #{vm_task.class.name})." unless ScirCloud.is_vm_task?(vm_task)
      vm_task.mount_directories # raises an exception if directories cannot be mounted
      command = job.qsub_command
      pid = vm_task.run_command_in_vm(command).gsub("\n","")
      return create_job_id(vm_task.id,pid)
    end

    private

    # The job id of a task executed in a VM is PID:VMID where VMID is
    # the CBRAIN task id of the VM task, and PID is the PID of the
    # task running in this VM. The following methods are helpers to
    # manipulate such strings.

    # Returns the task PID from the job id.
    def get_pid(jid)
      raise "Invalid job id" unless is_valid_jobid?(jid)
      s = jid.split(":")
      return s[2]
    end

    # Returns the VM id from the job id.
    def get_vm_id(jid)
      raise "Invalid job id" unless is_valid_jobid?(jid)
      s = jid.split(":")
      return s[1]
    end

    # Returns true if the job id is valid.
    def is_valid_jobid?(job_id)
      s=job_id.split(":")
      return false if s.size != 3
      return false if s[0] != "VM"
      return true
    end

    # Create a job id from VMID and PID.
    def create_job_id(vm_id,pid)
      raise "\"#{pid}\" doesn't look like a valid PID" unless pid.to_s.is_an_integer?
      return "VM:#{vm_id}:#{pid}"
    end

    # Assigns a VM to task and returns the task id of the VM.
    def schedule_task_on_vm(task)
      tool_config = ToolConfig.find(task.tool_config_id)

      # We use a lock here to avoid concurrency issues between
      # workers, which could lead to violations of the number of job
      # slots in VMs (and we really don't want this as it may slow
      # down or even crash a VM).
      File.open("#{Rails.root}/tmp/VMScheduler.lock", File::RDWR|File::CREAT, 0644) {|f|
        f.flock(File::LOCK_EX) # this will block until the lock is available.

        # The strategy implemented below is very basic and could be
        # improved in a number of ways. It basically aims at packing
        # all the tasks in as few VMs as possible so that idle VMs can
        # be shut down.

        vms = CbrainTask.where(:type => "CbrainTask::StartVM",
                               :bourreau_id => task.bourreau_id,
                               :status => "On CPU").all
        suitable_vms = vms.select { |x|
          x.params[:disk_image ]   == tool_config.cloud_disk_image    &&
          x.params[:vm_user ]      == tool_config.cloud_vm_user       &&
          x.params[:instance_type] == tool_config.cloud_instance_type &&
          x.params[:vm_status]     == "booted"
          # do not filter on ssh parameters and boot timeout as long as the image is booted
        }.map { |x|
          [ x , get_number_of_free_slots_in_vm(x) ] # computes the number of free slot in each VM
        }.select { |x|
          x[1] > 0 # removes the VMs with no free slots
        }.sort!{ |a,b| b[1] <=> a[1] } # sorts VMs by increasing order of free slots so that we increase
                                       # the amount of idle VMs that we could shut down.
        raise(NoVmAvailableError, "Cannot match task #{task.id} to VM.") if suitable_vms.empty?
        vm_id = suitable_vms[0][0].id
        tvma = TaskVmAllocation.new
        tvma.vm_id = vm_id # yes, if the VM has been terminated since
                           # this method started, we are doomed (this
                           # is a race condition). To avoid that, a
                           # lock should be taken on the VM (using a
                           # status transition as implemented in
                           # ClusterTask.submit_subtasks_from_json)
                           # and the status of the VM should be
                           # checked within the protected section. If
                           # the status is terminated (or on hold, or
                           # suspended), we should fall back on the
                           # next available VM.
        tvma.task_id = task.id
        tvma.save!
        return vm_id
      }
    end

    # Computes the number of free job slots in a VM as the difference
    # between the number of job slots in the VM and the number of
    # active tasks in the VM.
    def get_number_of_free_slots_in_vm(vm_task)
      active_tasks = CbrainTask.where(:status => BourreauWorker::ReadyTasks , :bourreau_id => vm_task.bourreau_id).all
      active_task_ids = active_tasks.map { |x| x.id }
      n_tasks_in_vm = TaskVmAllocation.all.select { |x|
        x.vm_id == vm_task.id &&
        active_task_ids.include?(x.task_id)
      }.count
      return vm_task.params[:job_slots].to_i - n_tasks_in_vm
    end
  end

  # The JobTemplate class.
  class JobTemplate < Scir::JobTemplate

    def qsub_command
      cbrain_task = CbrainTask.find(task_id)
      # The method needs to return a string even if it is never used for a VM task.
      return "echo This is never executed" if ScirCloud.is_vm_task?(cbrain_task)

      # The task will be executed in a VM.
      command = qsub_command_scir_unix
      command+=" & echo \$!" #so that the command is backgrounded and its PID is returned
    end

    def shell_escape(s) #:nodoc:
      "'" + s.gsub(/'/,"'\\\\''") + "'"
    end

    def qsub_command_scir_unix #:nodoc:
      # This method is copied from scir unix, maybe there is a way to mutualize this code.
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

# Exception raised when no VM is available to execute a task
class NoVmAvailableError < StandardError
end
