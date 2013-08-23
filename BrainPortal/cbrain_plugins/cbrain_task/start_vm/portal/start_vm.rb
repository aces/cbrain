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

# A task to start a virtual machine 

class CbrainTask::StartVM < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:
  
  #TODO what's after_find ? (see nii2mnc.rb)

  def self.properties
    { :use_parallelizer => false }
  end  

  def self.default_launch_args
    {
      :disk_image => "default_disk_image.vdi",
      :qemu_params => "-boot d -net nic -net user -m 2g -localtime",
      :vnc_display => ":0",
      :emulation => "0",
      :vm_user => "root",
      :vm_boot_timeout => 60,
      :number_of_vms => 1,
      :job_slots => 1
    }
  end
  
  def self.pretty_params_names #:nodoc:
    @_ppn ||= {}
  end

  def before_form
    params = self.params
    ids    = params[:interface_userfile_ids]

    cb_error "Expecting a single user file as input, found #{ids.size}" unless ids.size == 1

    params[:disk_image]=ids[0]
    ""
  end

  def final_task_list
    task_list = [ ]
    params[:number_of_vms].to_i.times{
      task_list << self.dup
    }
    return task_list,""
  end

  

  def after_form #:nodoc:
    params = self.params

    cb_error "Missing disk image file!"  if params[:disk_image].blank?
    cb_error "Missing VM user!"  if params[:vm_user].blank?
    cb_error "Missing VM boot timeout!"  if params[:vm_boot_timeout].blank?
    cb_error "Missing number of job slots!" if params[:job_slots].blank?
    cb_error "Missing number of instances!" if params[:number_of_vms].blank?
    cb_error "Please don't try to start more than 20 instances at once for now." if params[:number_of_vms].to_i > 20

    #params[:vm_status] is the status of the VM embedded in the task.
    #For now we use a task param, maybe we'll create a VM object
    params[:vm_status] = "absent"

    #params[:vm_status_time] is the status timestamp
    #For now we use a task param, maybe we'll create a VM object
    params[:vm_status_time] = Time.now

    #params[:vm_jobs] contains the list of task ids that the VM executes
    #For now we use a task param, maybe we'll create a VM object
    params[:vm_tasks]=[]
    
    #params[:vm_local_ip] is the local IP of the worker node where the VM runs 
    #It will be used by the Bourreau worker to ssh to the VM
    #For now we use a task param, maybe we'll create a VM object
    params[:vm_local_ip]= nil 
    ""
  end
  
end
