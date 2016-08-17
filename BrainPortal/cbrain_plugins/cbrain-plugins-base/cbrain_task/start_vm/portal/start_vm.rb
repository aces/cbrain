
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
      :vm_user => "ec2-user",
      :vm_boot_timeout => 600,
      :number_of_vms => 1,
      :vm_ssh_tunnel_port => 1234,
      :job_slots => 2,
      :tag => "CBRAIN worker"
    }
  end
  
  def before_form #:nodoc:
    ""
  end
  
  def final_task_list #:nodoc:
    task_list = []
    params[:number_of_vms].to_i.times{
      task_list << self.dup
    }
    return task_list
  end

  def after_form #:nodoc:

    params = self.params

    errors = param_validation_errors
    unless errors.empty?
      errors.each_key do |key|
        params_errors.add(key,errors[key])
      end
    end

    # params[:vm_status] is the status of the VM started by the task.
    params[:vm_status] = "absent"

    # params[:vm_status_time] is the status timestamp
    params[:vm_status_time] = Time.now

    # params[:vm_local_ip] is the local IP of the worker node where the VM runs 
    # It will be used by the Bourreau worker to ssh to the VM
    params[:vm_local_ip]= nil 

    ""
  end
  
end
