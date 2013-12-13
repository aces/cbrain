# Scir class to handle tasks running inside VMs
# Didn't use the concept of session which is unclear to me. 
# This scir is only used as a "hijack" of the physical bourreau 
# The relevance of inheriting Scir is to be questioned
# Original author: Tristan Glatard

class ScirVM < Scir

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def run(job)
    task,vm_task = get_task_and_vm_task job

    check_mounts vm_task

    command = qsub_command(job)
    command.sub!(task.full_cluster_workdir,File.join(File.basename(RemoteResource.current_resource.cms_shared_dir),task.cluster_workdir)) #TODO (VM tristan) fix these awful substitutions #4769
    command.gsub!(task.full_cluster_workdir,"./")  
    command+=" & echo \$!" #so that the command is backgrounded and its PID is returned
    pid = run_command(command,vm_task).gsub("\n","")  
    if pid.to_s == "" then raise "Cannot submit job on VM #{vm_task.id}" end
    return create_job_id(vm_task.id,pid)
  end

  def job_ps(jid,caller_updated_at = nil)   
    vm_id,pid = get_vm_id_and_pid jid
    vm_task = get_task vm_id

    check_mounts vm_task

    command = "ps -p #{pid} -o pid,state | awk '$1 == \"#{pid}\" {print $2}'"
    status_letter = run_command(command,vm_task).gsub("\n","")
    return Scir::STATE_DONE if status_letter == "" #TODO (VM tristan) find a way to return STATE_FAILED when exit code was not 0
    return Scir::STATE_RUNNING if status_letter.match(/[srzu]/i)
    return Scir::STATE_USER_SUSPENDED if status_letter.match(/[t]/i)
    return Scir::STATE_UNDETERMINED
  end

  def hold(jid)
    true
  end

  def release(jid)
    true
  end
  
  def suspend(jid)
    vm_id,pid = get_vm_id_and_pid jid
    vm_task = get_task vm_id
    command = "kill -STOP #{pid}"
    run_command(command,vm_task)
  end

  def resume(jid)
    vm_id,pid = get_vm_id_and_pid jid
    vm_task = get_task vm_id
    command = "kill -CONT #{pid}"
    run_command(command,vm_task)
  end

  def terminate(jid)
    vm_id,pid = get_vm_id_and_pid jid
    vm_task = get_task vm_id
    command = "kill -TERM #{pid}"
    run_command(command,vm_task)
  rescue => ex
    raise ex unless ex.message.include? "Cannot establish connection with VM" #if the VM executing this task cannot be reached, then the task should be put in status terminated. Otherwise, if VM shuts down and the task is still in there, it could never be terminated.
  end

  def create_job_id(vm_id,pid)
    return "VM:#{vm_id}:#{pid}"
  end

  def is_valid_jobid?(job_id)
    return job_id.start_with?("VM:")
  end

  def get_vm_id_and_pid(jid)
    s = jid.split(":")
    raise "#{jid} doesn't look like a VM job id" unless ( s[0] == "VM" && s.size == 3 )
    return [s[1],s[2]]
  end

  def run_command(command,vm_task)
    master = get_ssh_master vm_task
    result = master.remote_shell_command_reader(command) {|io| io.read}
    return result 
  end
  
  def get_ssh_master(vm_task)
    user = vm_task.params[:vm_user]
    ip = vm_task.params[:vm_local_ip]
    port = vm_task.params[:ssh_port]
    master = SshMaster.find_or_create(user,ip,port)
    #tunnel used to sshfs from the VM to the host
    master.add_tunnel(:reverse,2222,'localhost',22) unless ( master.get_tunnels(:reverse).size !=0) 
    CBRAIN.with_unlocked_agent 
    master.start
    raise "Cannot establish connection with VM id #{vm_task.id} (#{master.ssh_shared_options})" unless master.is_alive?
    return master
  end
  
  def get_task(vm_id)
    CbrainTask.where(:id => vm_id).first
  end

  def get_task_and_vm_task(job)
    task = get_task job.task_id
    vm_id = task.vm_id
    vm_task = get_task vm_id
    return [task,vm_task]
  end

  def shell_escape(s) #:nodoc:
    "'" + s.gsub(/'/,"'\\\\''") + "'"
  end
    
  def qsub_command(job) #adapted from scir_unix
    raise "Error, this class only handle 'command' as /bin/bash and a single script in 'arg'" unless
      job.command == "/bin/bash" && job.arg.size == 1
    raise "Error: stdin not supported" if job.stdin

      stdout = job.stdout || ":/dev/null"
      stderr = job.stderr || (job.join ? nil : ":/dev/null")

      stdout.sub!(/^:/,"") if stdout
      stderr.sub!(/^:/,"") if stderr

      command = ""
      command += "cd #{shell_escape(job.wd)} || exit 20;"  if job.wd
      command += "/bin/bash #{shell_escape(job.arg[0])}"
      command += "  > #{shell_escape(stdout)}"
      command += " 2> #{shell_escape(stderr)}"              if stderr
      command += " 2>&1"                                    if job.join && stderr.blank?

      return command
    end

  def check_mounts vm_task
    # check if cache and task dirs are still mounted
    # this will also attempt to re-mount directories if mounts were broken
    # if directories still cannot be mounted, vm_task will be terminated 
    raise "Directories of VM #{vm_task.id} cannot be mounted" unless vm_task.mount_cache_dir && vm_task.mount_task_dir
  end
  
end
