
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

# A task starting a VM from a disk image.
class CbrainTask::StartVM < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:
  
  def self.properties #:nodoc:
    { :use_parallelizer => false }
  end  

  def self.default_launch_args #:nodoc:
    {
      :disk_image => 240, #centos disk image in test portal
      :qemu_params => "-boot d -net nic -net user -localtime",
      :emulation => "0",
      :vm_boot_timeout => 600,
      :number_of_vms => 1,
      :vm_cpus => 2,
      :vm_ram_gb => 4,
      :job_slots => 2,
      :cloud_image_type => "",
    }
  end
  
  def self.pretty_params_names #:nodoc:
    @_ppn ||= {}
  end

  def before_form #:nodoc:
    params = self.params
    ids    = params[:interface_userfile_ids]

    cb_error "Expecting a single user file as input, found #{ids.size}" unless ids.size == 1

    params[:disk_image]=ids[0]

    # Check if disk image is associated to a virtual bourreau
    virtual_bourreaux = DiskImageBourreau.where(:disk_image_file_id => params[:disk_image])
    cb_error "File id #{params[:disk_image]} is not associated to any Virtual Bourreau. You cannot start a VM with it." unless virtual_bourreaux.size != 0 
    cb_error "File id #{params[:disk_image]} has more than 1 Virtual Bourreau associated to it. This is not supported yet." unless virtual_bourreaux.size == 1
    virtual_bourreau = virtual_bourreaux.first

    params[:vm_user] = virtual_bourreau.disk_image_user

    bourreau = Bourreau.find(ToolConfig.find(self.tool_config_id).bourreau_id)
    if bourreau.cms_class.new.is_a? ScirCloud
      configured = false 
      virtual_bourreaux.each do |vb|
        if DiskImageConfig.where(:disk_image_bourreau_id => vb.id, :bourreau_id => bourreau.id).size >= 1
          configured = true
          break
        end
      end
      cb_error "Execution server #{bourreau.name} is not configured for disk image #{params[:disk_image]}" unless configured == true

      params[:available_types] = bourreau.scir_class.get_available_instance_types

    end
    ""
  end

  def final_task_list #:nodoc:
    task_list = [ ]
    params[:number_of_vms].to_i.times{
      task_list << self.dup
    }
    return task_list,""
  end

  def after_form #:nodoc:
    params = self.params

    # Note: bash escapes should be performed on bourreau side. Don't do them here because x.bash_escape.bash_escape != x.bash_escape

    begin
    validate_params # defined in common
    rescue => ex
      cb_error "#{ex.message}"
    end
    
    #params[:vm_status] is the status of the VM embedded in the task.
    #For now we use a task param, maybe we'll create a VM object
    params[:vm_status] = "absent"

    #params[:vm_status_time] is the status timestamp
    #For now we use a task param, maybe we'll create a VM object
    params[:vm_status_time] = Time.now

    #params[:vm_local_ip] is the local IP of the worker node where the VM runs 
    #It will be used by the Bourreau worker to ssh to the VM
    #For now we use a task param, maybe we'll create a VM object
    params[:vm_local_ip]= nil 
    ""
  end
  
end
