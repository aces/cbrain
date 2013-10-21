
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

class VMFactory 

  ActiveTasks = [ 'New', 'Setting Up', 'Queued', 'On CPU',  
                  'On Hold', 'Suspended',
                  'Post Processing',
                  'Recovering Setup', 'Recovering Cluster', 'Recovering PostProcess', # The Recovering states, not Recover
                  'Restarting Setup', 'Restarting Cluster', 'Restarting PostProcess', # The Restarting states, not Restart
                ]


  def initialize(arguments = {})
    log_vm "Creating new VM factory"
    #initializes round robin
    @next_site = 0 
  end

  def start

    tau = 10
    mu_plus = 1.3
    mu_minus = 0.5
    nu_plus = 5
    nu_minus = 5
    k_plus = 1 # in number of VMs
    k_minus = 1 # in number of VMs

    # TODO (Tristan) monitor all types of disk images separately. 
    while ( true )
      log_vm "Starting VMFactory iteration"
      
      # check upper bound
      time = 0
      while time < nu_plus do
        vms = get_active_vms
        load = self.measure_load vms
        if load >= mu_plus then log_vm "Load has been too HIGH for #{time}s" else break end
        sleep 1
        time = time + 1
      end
      if time >= nu_plus then (1..k_plus).each { 
          site_name,bourreau_id,tool_config = self.select_site_round_robin
          self.submit_vm site_name,bourreau_id,tool_config
        } end

      #check lower bound
      time = 0
      while time < nu_minus do
        vms = get_active_vms
        if vms.count != 0 && load <= mu_minus && ( vms.count != 1 || load == 0 ) then log_vm "Load has been too LOW for #{time}s" else break end
        sleep 1
        load = self.measure_load vms
        time = time + 1
      end
      if time >= nu_minus then (1..k_minus).each { remove_vm } end    
      sleep tau
    end
  end

  def get_active_vms
    return vms = CbrainTask.where(:status => ActiveTasks, :type => "CbrainTask::StartVM")
  end

  def measure_load vms
    # TODO (Tristan) measure only tasks going to a particular disk image
    # TODO (Tristan) do this with only 1 query, written as an SQL string (Active Record doesn't seem to support NOT)
    tasks = (CbrainTask.where(:status => ActiveTasks) - CbrainTask.where(:type => "CbrainTask::StartVM")).count
    log_vm "There are #{tasks} active tasks"
    # sum total job slots in VMs
    log_vm "There are #{vms.count} active VMs"
    job_slots = 0 
    vms.each do |x| 
      job_slots += x.params[:job_slots].to_i
    end
    #log_vm "There are #{job_slots} job_slots in active VMs"
    load = Float::INFINITY
    if tasks == 0 then 
      load = 0 
    else
      if job_slots != 0 then load = tasks.to_f/job_slots.to_f  end
    end
    log_vm "Load is #{load.to_s.colorize(33)}"
    return load
  end

  def select_site_round_robin 
    site_names = ["Nimbus","Colosse","Guillimin", "Mammouth"] 
    bourreau_ids = [21, 18, 19, 20]
    tool_configs = [13, 8, 9, 11]
    @next_site = (@next_site + 1) % site_names.length
    return [site_names[@next_site],bourreau_ids[@next_site],tool_configs[@next_site]]
  end
  
  def submit_vm(site_name, bourreau_id, tool_config)
    log_vm "Submitting a new VM to #{site_name.colorize(33)}"
    task = CbrainTask.const_get("StartVM").new
    task.params = task.class.wrapper_default_launch_args.clone
    task.params[:vm_user] = "root" 
    task.user = User.where(:login => "admin").first
    task.bourreau_id = bourreau_id
    task.tool_config = ToolConfig.find(tool_config) 
    task.status = "New" 
    task.save!
    Bourreau.find(task.bourreau_id).send_command_start_workers rescue true

  end

  def remove_vm
    log_vm "Removing a VM"
    # get queuing VMs
    queued = CbrainTask.where(:type => "CbrainTask::StartVM", :status => [ 'New','Queued', 'Setting Up'] )
    log_vm "There are #{queued.count} queued VMs"
    youngest_queued = nil 
    queued.each do |task|
      if youngest_queued == nil || youngest_queued.updated_at < task.updated_at then youngest_queued = task end
    end
    if youngest_queued != nil then
      # race condition: VM may not be queuing any more at this point
      log_vm "Terminating queuing VM id #{youngest_queued.id}" 
      terminate_vm youngest_queued.id
    else
      # get booting VMs 
      on_cpu = CbrainTask.where(:type => "CbrainTask::StartVM", :status => [ 'On CPU'] )
      booting = []
      on_cpu.each do |task| 
        if task.params[:vm_status] == "booting" then booting << task end
      end
      log_vm "There are #{booting.count} booting VMs"
      youngest_booting = nil 
      booting.each do |task|
        if youngest_booting == nil || youngest_booting.updated_at < task.updated_at then youngest_booting = task end
      end
      if youngest_booting != nil then 
        log_vm "Terminating booting VM id #{youngest_booting.id}"
        # race condition: VM may not be booting any more at this point
        terminate_vm youngest_booting.id
      else
        # get idle VMs
        idle = []
        on_cpu.each do |task|
          if task.params[:vm_status] == "booted" and CbrainTask.where(:vm_id => task.id,:status=>ActiveTasks).count == 0
          then idle << task end
        end
        log_vm "There are #{idle.count} idle VMs"
        # oldest idle
        oldest_idle = nil
        idle.each do |task|
          if oldest_idle == nil || oldest_idle.updated_at > task.updated_at then oldest_idle = task end
        end
        if oldest_idle != nil then 
          log_vm "Terminating idle VM id #{oldest_idle.id}"
          # race condition again
          terminate_vm oldest_idle.id
        end
      end
    end
  end

  def terminate_vm(id)
    task = CbrainTask.where(:id => id).first
    Bourreau.find(task.bourreau_id).send_command_alter_tasks(task, PortalTask::OperationToNewStatus["terminate"], nil, nil)
  end

end
