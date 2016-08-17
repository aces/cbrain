
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

require 'net/ssh'

# A task that starts a VM, monitors its booting process using ssh, and
# mounts the Bourreau task and data directories in it using sshfs.
class CbrainTask::StartVM < ClusterTask

  Revision_info = CbrainFileRevision[__FILE__]

  # A Hook used to follow the boot process of the VM once it is
  # running.
  after_status_transition '*', 'On CPU', :starting

  def setup #:nodoc:
    errors = param_validation_errors
    return true if errors.empty?
    errors.each_key do |key|
      addlog(errors[key])
    end
    return false
  end
  
  def cluster_commands #:nodoc:
    [ "echo This will never execute" ]  # If the cluster commands are
                                        # empty, task will jump directly
                                        # to state data ready, which we don't want to happen.
                                        # In a StartVM task, the cluster_commands are never executed.
                                        # The task is implemented by starting a new VM using the cloud API.
                                        # No bash script execution is involved.
  end
  
  def save_results #:nodoc:
    addlog("No result to save.")
    # We consider the task successful if the VM booted. 
    return true if params[:vm_status] == "booted"
    addlog "VM is not active and never booted. I don't know why, sorry."
    return false
  end

  # Hook called when the VM task gets on CPU. 
  # Monitors the VM until it boots. Then mounts shared directories with sshfs. 
  def starting(init_status) #:nodoc:
    params = self.params

    # Updates VM local IP now that it is running.
    params[:vm_local_ip] = scir_session.get_local_ip(id)
    if params[:vm_local_ip].blank? 
      addlog "Cannot get VM local IP. Terminating VM task (id = #{id})."
      update_vm_status("unreachable")
      save!
      terminate
    end
    update_vm_status("booting")
    save! 

    # Monitors the VM until it has booted.
    CBRAIN.spawn_with_active_records("Monitor VM")  do
      begin
        monitor_to_boot
        mount_directories
        addlog("VM has booted")
        update_vm_status("booted")
        save!
      rescue => ex
        addlog "#{ex.class} #{ex.message}"
      end	
    end
  end

  # Updates VM parameters with the new VM status and status time.
  def update_vm_status(new_status) #:nodoc:
    params[:vm_status] = new_status
    params[:vm_status_time] = Time.now
  end

  # Mounts cache and task directories.
  def mount_directories #:nodoc:
    addlog("Mounting shared directories")
    mount_cache_dir
    mount_task_dir
  end

  # Monitors the VM until it has booted. 
  def monitor_to_boot() #:nodoc:
    start_time = Time.now
    booted = false
    while !booted do
      break if ( Time.now - start_time ) > params[:vm_boot_timeout].to_f
      sleep 5
      booted = booted?
    end
    return if booted
    addlog("Boot timeout reached. Terminating VM task (id = #{id}).")
    update_vm_status("unreachable")
    save!
    terminate
  end

  # Checks if the VM has booted by trying to connect with ssh.
  def booted? #:nodoc:
    addlog("Trying to ssh #{params[:vm_user]}@#{params[:vm_local_ip]}")
    master = get_ssh_master_for_vm
    return true
  rescue => ex
    addlog "Error: #{ex.message}"
    return false
  end

  # Mounts the cache directory in the VM.
  def mount_cache_dir #:nodoc:
    full_cache_dir = RemoteResource.current_resource.dp_cache_dir
    if full_cache_dir.blank? 
      addlog("No cache directory configured")
      return
    end
    local_cache_dir = File.basename(full_cache_dir)
    mount_dir(full_cache_dir,local_cache_dir)
    return true
  rescue => ex
    addlog("Cannot mount cache directory (#{ex.message}). Terminating VM task.")
    terminate
    return false
  end

  # Mounts the task directory in the VM. 
  def mount_task_dir #:nodoc:
    bourreau_shared_dir = bourreau.cms_shared_dir
    mount_dir bourreau_shared_dir,File.basename(bourreau_shared_dir)
    return true
  rescue => ex
    addlog "Cannot mount task directory (#{ex.message}). Terminating VM task."
    terminate
    return false
  end

  # Mounts a directory in the VM.
  # local_dir is the VM directory.
  # remote_dir is the directory on the Bourreau machine.
  def mount_dir(remote_dir,local_dir) #:nodoc:
    return unless !is_mounted? remote_dir,local_dir
    user = ENV['USER'] #quite unix-specific, sorry...

    # A reverse ssh tunnel from the Bourreau
    # to the VM is initiated on port param[:vm_ssh_tunnel_port] in method
    # 'get_ssh_master_for_vm' called by 'run_command_in_vm'.
    sshfs_command = "mkdir #{local_dir} -p ; umount #{local_dir} ; sshfs -p #{params[:vm_ssh_tunnel_port]} -C -o nonempty -o follow_symlinks -o reconnect -o ServerAliveInterval=15 -o StrictHostKeyChecking=no #{user}@localhost:#{remote_dir} #{local_dir}"
    
    addlog "Mounting dir: #{sshfs_command}"
    addlog run_command_in_vm(sshfs_command) 
    sleep 5  # Leave time to fuse to mount the dir

    raise "Couldn't mount local directory #{local_dir} as #{remote_dir} in VM" unless is_mounted?(remote_dir,local_dir)
  end

  # Checks if a directory is mounted in the VM. We do this by editing
  # a file in the mounted directory (Bourreau side) and checking that
  # the file content propagates to the directory in the VM. local_dir
  # is the directory in the VM. remote_dir is the directory on the
  # Bourreau machine.
  def is_mounted?(remote_dir,local_dir) #:nodoc:
    @result_cache = Hash.new unless !@result_cache.blank? # this hash will contain the results of
                                                          # the last mount tests.
    timestamp_written = Time.now
    test_file_name = ".testmount.#{Process.pid}"
    if File.exist?(test_file_name)
      last_checked = File.mtime(test_file_name) # the modification time of the test file tells us when
                                                # we last checked that the directory was mounted.
      
      # Returns the cached result if it exists and was evaluated less than 5s.
      return @result_cache[combine(remote_dir,local_dir)] if ( (timestamp_written - last_checked < 5) &&
                                                               !@result_cache[combine(remote_dir,local_dir)].blank? )
    end
    
    addlog "Checking if local directory #{remote_dir} is mounted in #{local_dir} in VM"
    # Writes the timestamp in the mounted directory (on Bourreau side).
    begin
      file = File.open(File.join(remote_dir,test_file_name), "w")
      file.write(timestamp_written.to_s)
    rescue IOError => e
      raise e
    ensure
      file.close unless file == nil
    end
    # Now read the file on the other end
    timestamp_read = run_command_in_vm("cat #{local_dir}/#{test_file_name}")
    # Directory is mounted if the written and read timestamps are the same.
    result = ( timestamp_written.to_s == timestamp_read.to_s ) ? true : false
    @result_cache[combine(remote_dir,local_dir)] = result
    return result
  ensure
    File.delete(File.join(remote_dir,test_file_name))
  end

  # Returns a key unique to a combination of directories.
  # Uses ; because this char is not supposed to be included in a directory name. 
  def combine(a,b) #:nodoc:
    return "#{a};;;#{b}"
  end

  # Gets an ssh connection to the VM. Also, initiates a reverse tunnel
  # on port param[:vm_ssh_tunnel_port] so that the VM can connect to
  # the Bourreau host by doing ssh -p #{param[:vm_ssh_tunnel_port]
  # [user]@localhost. This tunnel is used to mount Bourreau
  # directories in the VM using sshfs (see method mount_dir).
  def get_ssh_master_for_vm #:nodoc:
    user   = params[:vm_user]
    ip     = params[:vm_local_ip]
    port   = params[:ssh_port]
    master = SshMaster.find_or_create(user,ip,port)

    # Tunnel used to sshfs from the VM to the host.
    master.add_tunnel(:reverse,params[:vm_ssh_tunnel_port].to_i,'localhost',22) unless ( master.get_tunnels(:reverse).size !=0) 
    CBRAIN.with_unlocked_agent 
    master.start
    raise "Cannot establish connection with VM id #{id} (#{master.ssh_shared_options})" unless master.is_alive?
    return master
  end

  # Runs command 'command' in the VM, through ssh.
  def run_command_in_vm(command) #:nodoc:
    master = self.get_ssh_master_for_vm
    result = master.remote_shell_command_reader(command) {|io| io.read}
    return result 
  end

end      
