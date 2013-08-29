# Scir class to handle tasks running inside VMs
# Didn't use the concept of session which is unclear to me. 
# This scir is only used as a "hijack" of the physical bourreau 
# The relevance of inheriting Scir is to be questioned
# Original author: Tristan Glatard

class ScirVM < Scir

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def run(job)
    task,vm_task = get_task_and_vm_task job
    command = job.qsub_command
    command.sub!(task.full_cluster_workdir,File.join(File.basename(RemoteResource.current_resource.cms_shared_dir),task.cluster_workdir)) #TODO (VM tristan) fix these awful substitutions
    command.gsub!(task.full_cluster_workdir,"./")  
    command+=" & echo \$!" #so that the command is backgrounded and its PID is returned
    pid = run_command(command,vm_task).gsub("\n","")  
    return create_job_id(vm_task.id,pid)
  end

  def job_ps(jid,caller_updated_at = nil)   
    vm_id,pid = get_vm_id_and_pid jid
    vm_task = get_task vm_id
    command = "ps -p #{pid} -o pid,state | awk '$1 == \"#{pid}\" {print $2}'"
    status_letter = run_command(command,vm_task).gsub("\n","")
    return Scir::STATE_DONE if status_letter == "" #TODO (VM tristan) find a way to return STATE_FAILED when exit code was not 0
    return Scir::STATE_RUNNING if status_letter.match(/[srzu]/i)
    return Scir::STATE_USER_SUSPENDED if status_letter.match(/[t]/i)
    return Scir::STATE_UNDETERMINED
  end

  def create_job_id(vm_id,pid)
    return "VM:#{vm_id}:#{pid}"
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
    #TODO (VM tristan) find a way to have a singleton connection per vm_task
    user = vm_task.params[:vm_user]
    ip = vm_task.params[:vm_local_ip]
    port = vm_task.params[:ssh_port]
    master = SshMaster.find_or_create(user,ip,port)
    master.add_tunnel(:reverse,2222,'localhost',22) unless ( master.get_tunnels(:reverse).size !=0) #tunnel used to sshfs from the VM to the host
    CBRAIN.with_unlocked_agent 
    master.start
    raise "Cannot establish connection with VM id #{vm_task.id} (#{user}@#{ip}:#{port})" unless master.is_alive?
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

end
