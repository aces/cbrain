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

require 'openstack'

class CbrainTask::StartVM < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:
  
  def self.properties
    { :use_parallelizer => false }
  end  

  def self.default_launch_args
    {
      :disk_image => 240, #centos disk image in test portal
      :qemu_params => "-boot d -net nic -net user -localtime",
      :emulation => "0",
      :vm_boot_timeout => 600,
      :number_of_vms => 1,
      :vm_cpus => 2,
      :vm_ram_gb => 4,
      :job_slots => 2,
      :open_stack_image_flavor => "",
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

    # Check if disk image is associated to a virtual bourreau
    virtual_bourreaux = Bourreau::DiskImageBourreau.where(:disk_image_file_id => params[:disk_image])
    cb_error "File id #{params[:disk_image]} is not associated to any Virtual Bourreau. You cannot start a VM with it." unless virtual_bourreaux.size != 0 
    cb_error "File id #{params[:disk_image]} has more than 1 Virtual Bourreau associated to it. This is not supported yet." unless virtual_bourreaux.size == 1

    virtual_bourreau = virtual_bourreaux.first

    params[:vm_user] = virtual_bourreau.disk_image_user

    bourreau = Bourreau.find(ToolConfig.find(self.tool_config_id).bourreau_id)
    if bourreau.cms_class == "ScirOpenStack"
      username = bourreau.open_stack_user_name
      password = bourreau.open_stack_password
      auth_url = bourreau.open_stack_auth_url
      tenant_name = bourreau.open_stack_tenant
      os = OpenStack::Connection.create({:username => username, :api_key=> password, :auth_method=>"password", :auth_url => auth_url, :authtenant_name =>tenant_name, :service_type=>"compute"})
      
      params[:available_flavors] =  Array.new
      os.list_flavors.each do |flavor|
        params[:available_flavors] << [ flavor[:name].to_s , flavor[:id].to_s]
      end
    end
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

    cb_error "Missing number of instances!" if params[:number_of_vms].blank? 
    cb_error "Please don't try to start more than 20 instances at once for now." if params[:number_of_vms].to_i > 20

    bourreau = Bourreau.find(ToolConfig.find(self.tool_config_id).bourreau_id)
    cb_error "Missing number of job slots!" if params[:job_slots].blank? 
    cb_error "Missing number of CPUs !" if params[:vm_cpus].blank? && bourreau.cms_class != "ScirOpenStack"
    cb_error "Missing RAM!" if params[:vm_ram_gb].blank? && bourreau.cms_class != "ScirOpenStack"
    cb_error "Missing OpenStack flavor" if params[:open_stack_image_flavor].blank? && bourreau.cms_class == "ScirOpenStack"

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
