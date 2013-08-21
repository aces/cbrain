# Scir class to handle tasks running inside VMs
# Original author: Tristan Glatard
class ScirVM < Scir
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def run(job)
    #select a VM where to run the job
    task_id = job.task_id
    task = CbrainTask.where(:id => task_id).first      
    
    vm_id = task.params[:vm_id]
    vm_task = CbrainTask.where(:id => vm_id).first
    
    #create the remote dir
    create_task_dir(task,vm_task)
    
    #mount it locally
    task_dir = task.full_cluster_workdir
    mount = File.join(task_dir,"mount")
    Dir.mkdir(mount)
    mount_dir(mount,task.cluster_workdir,vm_task)
    
    #link files 
    Dir.entries(task_dir).each{ |x| 
      #TODO (VM tristan) fix this cp
      FileUtils.cp(File.join(task_dir,x),File.join(mount,x)) unless ( x == "mount" || x == "." || x == "..")
    }
    
    #launch process
    command = job.qsub_command
    command.sub!(task.full_cluster_workdir,task.cluster_workdir) #TODO (VM tristan) fix these awful substitutions
    command.gsub!(task.full_cluster_workdir,"./")
    
    pid = run_command(command,vm_task)
    
    return "#{vm_id}:#{pid}"
  end

  def run_command(command,vm_task)
    master = get_ssh_master vm_task
    master.remote_shell_command_reader command
    master.stop
    return 1234 #TODO return PID
  end
  
  def mount_dir(local_dir,remote_dir,vm_task)
    #TODO (VM tristan) use CBRAIN's agent instead of system call
    user = vm_task.params[:vm_user]
    ip = vm_task.params[:vm_local_ip]
    port = vm_task.params[:ssh_port]
    command = "sshfs -p #{port} #{user}@#{ip}:#{remote_dir} #{local_dir}"
    Kernel.system(command)
  end

  def create_task_dir(task,vm_task)
    command = "mkdir -p ./#{task.cluster_workdir}"
    run_command(command,vm_task)
  end
  
  def get_ssh_master(vm_task)
    #TODO (VM tristan) find a way to have a singleton connection per vm_task
    user = vm_task.params[:vm_user]
    ip = vm_task.params[:vm_local_ip]
    port = vm_task.params[:ssh_port]
    master = SshMaster.find_or_create(user,ip,port)
    CBRAIN.with_unlocked_agent 
    master.start
    raise "Cannot establish connection with VM id #{vm_task.id} (#{user}@#{ip}:#{port})" unless master.is_alive?
    return master
  end

end
