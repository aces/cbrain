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

#a task starting a VM from a disk image 

require 'net/ssh'

class CbrainTask::StartVM < ClusterTask
  
  Revision_info = CbrainFileRevision[__FILE__]

  #to update the status of the VM embedded in the task
  after_status_transition '*', 'On CPU', :starting
  
  def setup 
    #synchronize VM disk image

    disk_image_file_id = params[:disk_image]
    addlog "Synchronizing file with id #{disk_image_file_id}"
    disk_image_file = Userfile.find(disk_image_file_id) 

    timestart = Time.now
    disk_image_file.sync_to_cache  
    #TODO make a copy in the task work dir so that each VM has its own
    timestop = Time.now
    difftime = timestop - timestart 
    self.addlog "Synchronized file #{disk_image_file.name} in #{difftime}s"

    disk_image_filename = disk_image_file.cache_full_path 
    safe_symlink(disk_image_filename,"image")

    if !File.exists? disk_image_filename
      raise "File #{disk_image_filename} can't be found after synchronization."
    end
    
 
  true
  end

  def job_walltime_estimate
    24.hours
  end

  def cluster_commands
    params = self.params
    snapshot_name = "image-snapshot-#{self.id}"
    snapshot_creation = "qemu-img create -f qcow2 -b image #{snapshot_name}"

    #TODO (VM tristan) may fail in case someone (not us) already uses this port on the host
    ssh_port = 2200 + ( self.id % 3000 ) #make sure this doesn't overlap with display ports which typically start at 5900
    self.params[:ssh_port] = ssh_port
    display_port = ( self.id % 100 )
    self.params[:vnc_display] = display_port
    self.save
    
    command = "#{snapshot_creation} ; "

    if mybool(params[:emulation])
      then 
      command << "qemu-system-x86_64"
      else
      command << "qemu-kvm"
    end
    command << " -hda #{snapshot_name} -redir tcp:#{params[:ssh_port]}::22 -display vnc=:#{params[:vnc_display]} #{params[:qemu_params]}"
    commands = [
                "echo \"Command: #{command}\"",
                command
               ]
    return  commands
  end
  
  def save_results
     addlog "No result to save"
    true
  end
  
  #taken from task civet
  def mybool(value) #:nodoc:
      return false if value.blank?
      return false if value.is_a?(String)  and value == "0"
      return false if value.is_a?(Numeric) and value == 0
      return true
  end
  
  def starting(init_status)
    addlog "VM task #{self.id} is on CPU"
    params = self.params

    #update VM params
    params[:vm_local_ip] = self.scir_session.get_local_ip(self.id)
    self.update_vm_status "booting" 
    self.save! #will launch an exception if save fails

    #monitor VM until it's booted
    CBRAIN.spawn_with_active_records("Monitor VM")  do
      self.monitor_to_boot
    end
  end
  
  def update_vm_status(new_status)
    params[:vm_status] = new_status
    params[:vm_status_time] = Time.now
  end
  
  def monitor_to_boot
    start_time = Time.now
    while !booted? do
      elapsed = Time.now - start_time
#      addlog "Elapsed time is #{elapsed}s, timeout is #{params[:vm_boot_timeout]}, timedout? #{elapsed > params[:vm_boot_timeout].to_f}"
      if elapsed > params[:vm_boot_timeout].to_f
      then
        addlog "Boot timeout reached. Terminate VM task (id = #{self.id})."
        update_vm_status("unreachable")
        self.save!
        #TODO terminate doesn't work
        self.terminate
        return 
      end
      sleep 5
    end
    
    addlog "Mounting shared directories"
    mount_cache_dir
    mount_task_dir

    
    #WM has booted
    addlog "VM has booted"
    update_vm_status("booted")
    self.save!
  end
  
  def booted?
    #TODO (VM tristan) use Pierre's ssh lib instead
    addlog "Trying to ssh -p #{params[:ssh_port]} #{params[:vm_user]}@#{params[:vm_local_ip]}"
    
    user = params[:vm_user]
    ip = params[:vm_local_ip]
    port = params[:ssh_port]

    s = ScirVM.new
    master = s.get_ssh_master self
    return true
  rescue => ex
    return false
  end
  
  def mount_cache_dir
    full_cache_dir = RemoteResource.current_resource.dp_cache_dir
    if full_cache_dir.blank? 
      addlog "No cache directory configured"
      return
    end
    local_cache_dir = File.basename(full_cache_dir)
    mount_dir full_cache_dir,local_cache_dir
  rescue => ex
    addlog "#{ex.class} #{ex.message}"
  end
  
  def mount_task_dir
    bourreau_shared_dir = self.bourreau.cms_shared_dir
    mount_dir bourreau_shared_dir,File.basename(bourreau_shared_dir)
  rescue => ex
    addlog "#{ex.class} #{ex.message}"
  end
  
  def mount_dir(remote_dir,local_dir)
    scir = ScirVM.new
    user = ENV['USER'] #quite unix-specific...
    sshfs_command = "mkdir #{local_dir} -p ; sshfs -p 2222 -C -o follow_symlinks -o reconnect -o StrictHostKeyChecking=no #{user}@localhost:#{remote_dir} #{local_dir}" #TODO (VM tristan) put this 2222 somewhere in config
    addlog "Mounting dir: #{sshfs_command}"
    addlog scir.run_command(sshfs_command,self) 
  rescue => ex
    addlog "#{ex.class} #{ex.message}"
  end

end      
