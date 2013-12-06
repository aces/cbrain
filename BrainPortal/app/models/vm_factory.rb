
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


# An abstract class to start/stop virtual machines based on the system load
# Derived classes must implement method submit_vm

class VmFactory < ActiveRecord::Base

  # see #5061. Be careful, this list is different from the list in BourreauWorker
  ActiveTasks = [ 'New', 'Setting Up', 'Queued', 'On CPU',  
                  'On Hold', 'Suspended',
                  'Post Processing',
                  'Recovering Setup', 'Recovering Cluster', 'Recovering PostProcess', # The Recovering states, not Recover
                  'Restarting Setup', 'Restarting Cluster', 'Restarting PostProcess', # The Restarting states, not Restart
                ]
 
  def initialize(disk_image_file_id,tau,mu_plus,mu_minus,nu_plus,nu_minus,k_plus,k_minus)
   
    @disk_image_file_id = disk_image_file_id
di =  DiskImageBourreau.where(:disk_image_file_id => disk_image_file_id).first#Userfile.find(disk_image_file_id).name
    @disk_image_name = di.blank? ? "Void" : di.name

    #initialize threshold parameters
    @tau = tau #= 10
    @mu_plus = mu_plus #1.3
    @mu_minus = mu_minus #0.5
    @nu_plus = nu_plus #5
    @nu_minus = nu_minus #5
    @k_plus = k_plus #1 # in number of VMs
    @k_minus = k_minus #1 # in number of VMs

    # initialize StartVM tool id
    @start_vm_tool_id = Tool.where(:cbrain_task_class => "CbrainTask::StartVM").first.id
    log_vm "Creating new VM factory"    
  end

  def log_vm(object)
    t = Time.new
    logfile = "log/factory.log"
    text = object.respond_to?("message") ? "#{object.message}  #{object.backtrace}".colorize(32) : "#{object}"
    time = "[ #{t.to_i} #{t.inspect} ]"
    prompt = "VM>"
    out = "#{prompt.colorize(36)} #{time.colorize(36)} #{@disk_image_name.colorize(33)} \t #{text}\n"
    File.open(logfile, 'a') {|f| f.write(out) }
  end

  # The main loop controlling VM submission and removal
  # See Algorithm 1 in CCGrid 2014 paper
  def start
    while ( true )
      log_vm "Starting VMFactory iteration"
      # check upper bound
      time = 0
      while time < @nu_plus do
        vms = get_active_vms_without_replicas
        load = self.measure_load vms
        if load >= @mu_plus then log_vm "Load  has been too "+"HIGH".colorize(32)+" for #{time}s" else break end
        sleep 1
        time = time + 1
      end
      if time >= @nu_plus then (1..@k_plus).each { |i|
          log "Submiting VM #{i} of #{@k_plus}"
          submit_vm
        } 
      end
      #check lower bound
      time = 0
      while time < @nu_minus do
        vms = get_active_vms_without_replicas
        if vms.count != 0 && load <= @mu_minus && ( vms.count != 1 || load == 0 ) then log_vm "Load  has been too " +"LOW".colorize(32)+" for #{time}s" else break end
        sleep 1
        load = self.measure_load vms
        time = time + 1
      end
      if time >= @nu_minus then (1..@k_minus).each { remove_vm } end    
      handle_replicas
      sleep @tau
    end
  end

  def get_active_vms_without_replicas
    # get only 1 VM from every set of replicas
    vms = get_active_vms
    replica_ids = Array.new
    result = Array.new
    vms.each do |task|
      if not replica_ids.include? task.id then
        result << task 
        if not task.params[:replicas].blank? then
          task.params[:replicas].each do |replicated_task|
            replica_ids << replicated_task
          end
        end
      end
    end
    return result
  end

  def get_active_vms
    vms = CbrainTask.where(:status => ActiveTasks, :type => "CbrainTask::StartVM")
    #reject vms of offline bourreaux
    vms_online = vms.reject{ |x| !Bourreau.find(x.bourreau_id).online }
    #reject vms with the wrong disk image
    vms_with_good_disk_image = vms_online.reject{ |x| x.params[:disk_image] != @disk_image_file_id || Bourreau.find(x.bourreau_id).online == false}
    
    log_vm "There are #{vms_with_good_disk_image.count} active VMs (including replicas)"
    return vms_with_good_disk_image
  end

  def measure_load vms
    disk_images = DiskImageBourreau.where(:disk_image_file_id => @disk_image_file_id)
    tasks = 0
    disk_images.each do |b|
      log_vm "Checking active tasks"
      tasks += CbrainTask.where(:status => ActiveTasks, :bourreau_id => b.id).count
    end
    log_vm "There are #{tasks} active tasks"
    # sum total job slots in VMs
    log_vm "There are #{vms.count} active VMs (excluding replicas)"
    job_slots = 0 
    vms.each do |x| 
      job_slots += x.params[:job_slots].to_i
    end
    load = Float::INFINITY
    if tasks == 0 then 
      load = 0 
    else
      if job_slots != 0 then load = tasks.to_f/job_slots.to_f  end
    end
    log_vm "Load is #{load.to_s.colorize(33)}"
    return load
  end

  def get_active_tasks(bourreau_id)
    return CbrainTask.where(:bourreau_id => bourreau_id,:status => ActiveTasks,:type => "CbrainTask::StartVM").count
  end

  def submit_vm
    raise "Abstract method. Must be implemented by child classes."
  end

  # method to submit and replicate VMs on a set of sites
  def submit_vm_and_replicate(bourreau_ids)
    task_replicas = Array.new
    task_ids = Array.new 
    bourreau_ids.each do |i|
      bourreau = Bourreau.find(i)
      if get_active_tasks(i) < bourreau.meta[:task_limit_total].to_i || bourreau.meta[:task_limit_total].to_i == 0 || bourreau.meta[:task_limit_total].to_i.blank? then
        # will use the first config of StartVM on this bourreau
        tool_config = ToolConfig.where(tool_id: @start_vm_tool_id, bourreau_id: bourreau.id).first.id
        task = submit_vm_to_site(bourreau.name,bourreau.id,tool_config)
        if not task.blank? then
          task_replicas << task 
          task_ids << task.id
          task.params[:replicas] = Array.new
        end
      else
        log_vm "Not submitting VM to site #{bourreau.name} (max number of active VMs reached)"
      end
    end
    log_vm  "Submitted #{task_replicas.length} VMs"
    task_replicas.each { |t|
      t.params[:replicas].concat(task_ids)
      log_vm "Replicas of task #{t.id} are #{t.params[:replicas]}"
      t.save!
    }
  end
  
  def submit_vm_to_site(bourreau_id)

    bourreau = Bourreau.find(bourreau_id)    
    if not bourreau.online? then 
      log_vm  "Not".colorize(33) +" submitting VM to offline #{bourreau.name.colorize(33)}"
      return nil
    end
    
    log_vm "Submitting a new VM to #{bourreau.name.colorize(33)}"
    task = CbrainTask.const_get("StartVM").new
    task.params = task.class.wrapper_default_launch_args.clone

    # will submit with user associated to the first virtual bourreau we find with this disk image
    disk_image = DiskImageBourreau.where(:disk_image_file_id => @disk_image_file_id).first
    task.params[:vm_user] = disk_image.disk_image_user 
    task.user = User.where(:login => "admin").first
    task.bourreau_id = bourreau_id
    task.tool_config = ToolConfig.where(:tool_id => @start_vm_tool_id, :bourreau_id => bourreau.id).first
    task.status = "New" 
    task.params[:disk_image] = @disk_image_file_id
    
    if bourreau.cms_class == "ScirOpenStack" 
      task.params[:open_stack_image_flavor] = DiskImageConfig.where(:bourreau_id => bourreau.id, :disk_image_bourreau_id => disk_image.id).first.open_stack_default_flavor
    end

    task.save!
    Bourreau.find(task.bourreau_id).send_command_start_workers rescue true
    return task
  end

  def remove_vm
    return remove_vm_from_site    
  end

  # see Algorithm 2 in CCGrid 2014 paper
  def remove_vm_from_site(bourreau_id = nil)
    if bourreau_id.blank? then log_vm  "Removing a VM (site selection based on VM statuses)" else log_vm  "Removing a VM from site " + "#{Bourreau.find(bourreau_id).name}".colorize(33) end 
    # get queuing VMs # TODO get only VMs queued for this disk image
    queued_all = bourreau_id.blank? ? CbrainTask.where(:type => "CbrainTask::StartVM", :status => [ 'New','Queued', 'Setting Up'] ) : CbrainTask.where(:type => "CbrainTask::StartVM", :status => [ 'New','Queued', 'Setting Up'], :bourreau_id => bourreau_id )
    queued = queued_all.reject{ |x| x.params[:disk_image] != @disk_image_file_id || Bourreau.find(x.bourreau_id).online == false}
    log_vm "There are #{queued.count} queued VMs"
    youngest_queued = nil 
    queued.each do |task|
      if youngest_queued == nil || youngest_queued.updated_at < task.updated_at then youngest_queued = task end
    end
    if youngest_queued != nil then
      # race condition: VM may not be queuing any more at this point
      log_vm ( "Terminating".colorize(32)+" queuing VM id " + "#{youngest_queued.id}".colorize(33) )
      terminate_vm youngest_queued.id
      return youngest_queued.id
    else
      # get booting VMs 
      on_cpu_all = bourreau_id.blank? ? CbrainTask.where(:type => "CbrainTask::StartVM", :status => [ 'On CPU'] ) : CbrainTask.where(:type => "CbrainTask::StartVM", :status => [ 'On CPU'], :bourreau_id => bourreau_id )
      on_cpu = on_cpu_all.reject{ |x| x.params[:disk_image] != @disk_image_file_id || Bourreau.find(x.bourreau_id).online == false}
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
        log_vm ("Terminating ".colorize(32)+"booting VM id " + "#{youngest_booting.id}".colorize(33)) 
        # race condition: VM may not be booting any more at this point
        terminate_vm youngest_booting.id
        return youngest_booting.id
      else
        # get idle VMs
        idle = []
        on_cpu.each do |task|
          if task.params[:vm_status] == "booted" and CbrainTask.where(:vm_id => task.id,:status=>ActiveTasks).count == 0
          then idle << task
          end
        end
        log_vm "There are #{idle.count} idle VMs"
        # oldest idle
        oldest_idle = nil
        idle.each do |task|
          if oldest_idle == nil || oldest_idle.updated_at > task.updated_at then oldest_idle = task end
        end
        if oldest_idle != nil then 
          log_vm ( "Terminating".colorize(32)+" idle VM id "+ "#{oldest_idle.id}".colorize(33))
          # race condition again
          terminate_vm oldest_idle.id
          return oldest_idle.id
        end
      end
    end
    return nil 
  end

  def terminate_vm(id)
    task = CbrainTask.where(:id => id).first
    begin
      task.params[:timestamp_terminate_signal_sent] = Time.now 
      task.save!
      Bourreau.find(task.bourreau_id).send_command_alter_tasks(task, PortalTask::OperationToNewStatus["terminate"], nil, nil) 
    rescue => ex
      log_vm ex
    end
  end

  def get_ids_of_target_bourreaux
    Bourreau.where(:online => true).select(:id).map {|i| i.id } & ToolConfig.where(:tool_id => @start_vm_tool_id).select(:bourreau_id).map {|i| i.bourreau_id}
  end
  
  # See algorithm 2 in CCGrid 2014 paper
  def handle_replicas
    #handle replicas of OnCPU VMs
    on_cpu_all = CbrainTask.where(:type => "CbrainTask::StartVM", :status => [ 'On CPU'] )
    on_cpu = on_cpu_all.reject{ |x| x.params[:disk_image] != @disk_image_file_id || Bourreau.find(x.bourreau_id).online == false}
    on_cpu.each do |task|
      # task is now on cpu
      # r_id/r_task is its replicas
      # rr_id/rr_task is the removed replicas
      # rrr_id/rrr_tasks is the task referring to removed replicas

      #TODO (VM tristan) maybe remove condition on vm_status to reduce overhead
      if (not task.params[:replicas].blank?) && (not task.params[:replicas].count == 1) && task.params[:vm_status] == "booted" then 
        replica_ids = task.params[:replicas]-[task.id]
        log_vm "Task #{task.id} is OnCPU, has booted and has #{replica_ids.count} replicas. Removing VMs from these replicas' sites." unless replica_ids.blank?
        replica_ids.each do |r_id|
          if r_id != task.id then
            log_vm "Removing a task for replica #{r_id}"
            r_task = CbrainTask.find(r_id)
            r_bourreau_id = Bourreau.find(r_task.bourreau_id)
            rr_id = remove_vm_from_site r_bourreau_id 
            if not rr_id.blank? then
              #do the substitution trick
              rr_task = CbrainTask.find(rr_id)
              if not rr_task.params[:replicas].blank? then
                rr_task.params[:replicas].each do |rrr_id|
                  rrr_task = CbrainTask.find(rrr_id)
                  # replace RR by R in all RRR tasks
                  if not rrr_task.params[:replicas].blank? then
                    rrr_task.params[:replicas].map! { |x| x==rr_id ? r_id : x} #task referring to a removed replica now refers to the unremoved replica
                    rrr_task.save!
                  end
                  #we should add all rrr_id to r_task.replicas and remove task.id from id (see algo in paper)
                  if not r_task.params[:replicas].blank? then 
                    r_task.params[:replicas].map! { |x| x== task.id ? rrr_id : x} 
                    r_task.save!
                  end
                end
              end
            end
          end
        end
        task.params[:replicas] = [ task.id ]
        task.save
      end
    end    
  end

  # def update_site_queues
  #   0.upto(@n_sites-1) do |i|
  #     b = Bourreau.find(@bourreau_ids[i])
  #     @site_queues[i] = b.meta[:latest_in_queue_delay]
  #     log_vm "Updated queuing time of site #{@site_names[i]} to #{@site_queues[i]}"
  #   end
  # end

  # def update_site_booting_times
  #   0.upto(@n_sites-1) do |i|
  #     b = Bourreau.find(@bourreau_ids[i])
  #     @site_booting_times[i] = b.meta[:latest_booting_delay]
  #     log_vm "Updated booting of site #{@site_names[i]} to #{@site_booting_times[i]}"
  #   end
  # end

  # def update_site_performance_factors
  #   0.upto(@n_sites-1) do |i|
  #     b = Bourreau.find(@bourreau_ids[i])
  #     @site_performance_factors[i] = b.meta[:latest_performance_factor]
  #     log_vm "Updated booting of site #{@site_names[i]} to #{@site_booting_times[i]}"
  #   end
  # end
  
end  

