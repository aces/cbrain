
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

require "resolv-replace.rb" 

# A task starting a VM from a disk image.
class CbrainTask::StartVM < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:
  
  def self.properties #:nodoc:
    { :use_parallelizer => false }
  end  

  def self.default_launch_args #:nodoc:
    {
      :vm_user => "ec2-user",
      :vm_boot_timeout => 600,
      :number_of_vms => 1,
      :vm_ssh_tunnel_port => 1234,
      :job_slots => 2
    }
  end
  
  def self.pretty_params_names #:nodoc:
    @_ppn ||= {}
  end

  def before_form #:nodoc:
    params = self.params
    params[:available_disk_images] = bourreau.scir_class.get_available_disk_images(bourreau)
    params[:available_instance_types] = bourreau.scir_class.get_available_instance_types
    params[:available_ssh_key_pairs] = bourreau.scir_class.get_available_key_pairs(bourreau)
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
