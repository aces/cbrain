# A task to start a virtual machine - adapted from nii2mnc.rb

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
      :ssh_port => 2222,
      :vnc_display => ":0",
      :emulation => "0",
      :vm_user => "root",
      :vm_password => "home2013",
      :vm_boot_timeout => 60
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

  def after_form #:nodoc:
    params = self.params

    cb_error "Missing disk image file!"  if params[:disk_image].blank?
    cb_error "Missing ssh port!"  if params[:ssh_port].blank?
    cb_error "Missing VNC display!"  if params[:vnc_display].blank?
    cb_error "Missing VM user!"  if params[:vm_user].blank?
    cb_error "Missing VM password!"  if params[:vm_password].blank?
    cb_error "Missing VM boot timeout!"  if params[:vm_boot_timeout].blank?

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
