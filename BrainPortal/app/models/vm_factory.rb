
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

class String
  # Colorizes a string.
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end
end


# An abstract class to start/stop virtual machines based on the system load.
# Derived classes *must* implement method submit_vm.

class VmFactory < ActiveRecord::Base

  # See #5061. Be careful, this list is different from the list in BourreauWorker.
  ActiveTasks = [ 'New', 'Setting Up', 'Queued', 'On CPU',  
                  'On Hold', 'Suspended',
                  'Post Processing',
                  'Recovering Setup', 'Recovering Cluster', 'Recovering PostProcess', # The Recovering states, not Recover
                  'Restarting Setup', 'Restarting Cluster', 'Restarting PostProcess', # The Restarting states, not Restart
                ] #:nodoc:

  attr_accessible  :disk_image_file_id, :tau, :mu_plus, :mu_minus, :nu_plus, :nu_minus, :k_plus, :k_minus, :pid, :name
  
  after_save :my_initialize
  after_find :my_initialize

  def my_initialize #:nodoc:
    di =  DiskImageBourreau.where(:disk_image_file_id => disk_image_file_id).first
    @disk_image_name = di.blank? ? "Void" : di.name
    # initialize StartVM tool id
    @start_vm_tool_id = Tool.where(:cbrain_task_class => "CbrainTask::StartVM").first.id
  end

  # Logs colorized messages in log/factory.log.
  # Object may be exceptions (printed in red) or just strings. 
  def log_vm(object)
    t = Time.new
    logfile = "log/factory.log"
    text = object.respond_to?("message") ? "#{object.message}  #{object.backtrace}".colorize(32) : "#{object}"
    time = "[ #{t.to_i} #{t.inspect} ]"
    prompt = "VM>"
    out = "#{prompt.colorize(36)} #{time.colorize(36)} #{@disk_image_name.colorize(33)} \t #{text}\n"
    File.open(logfile, 'a') {|f| f.write(out) }
  end

  # Stops the VM factory.
  def stop
    log_vm "Killing pid #{self.pid}, bye!"
    Process.kill("KILL",self.pid)
  end

  # Stops all VM factories.
  def self.stop_all
    VmFactory.all.each{ |x| x.stop unless !x.alive? }
  end

  # Starts the main loop controlling VM submission and removal.
  # This loops will run in background until stopped. 
  # See Algorithm 1 in CCGrid 2014 paper.
  def start
    id = self.id
    CBRAIN.spawn_with_active_records("VM factory")  do
      begin
        log_vm "Launching VM factory #{id} for disk image #{self.disk_image_file_id}"
        factory = VmFactory.find(id)
        factory.pid = Process.pid
        factory.save!        
        while ( true )
          factory_iteration
          sleep self.tau
        end
      rescue => ex
        log_vm ex
      end
    end
  end
  
  def factory_iteration #:nodoc:
    log_vm "Starting VMFactory iteration"
    self.timestamp_of_last_iteration = Time.now
    # check upper bound
    time = 0
    while time < self.nu_plus do
      vms = get_active_vms_without_replicas
      load = self.measure_load vms
      if load >= self.mu_plus then log_vm "Load  has been too "+"HIGH".colorize(32)+" for #{time}s" else break end
      sleep 1
      time = time + 1
    end
    if time >= self.nu_plus then (1..self.k_plus).each { |i|
        log_vm "Submiting VM #{i} of #{self.k_plus}"
        submit_vm
      } 
    end
    #check lower bound
    time = 0
    while time < self.nu_minus do
      vms = get_active_vms_without_replicas
      if vms.count != 0 && load <= self.mu_minus && ( vms.count != 1 || load == 0 ) then log_vm "Load  has been too " +"LOW".colorize(32)+" for #{time}s" else break end
      sleep 1
      load = self.measure_load vms
      time = time + 1
    end
    if time >= self.nu_minus then (1..self.k_minus).each { remove_vm } end    
    handle_replicas
    save!

  end

  def get_active_vms_without_replicas #:nodoc:
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

  def get_active_vms #:nodoc:
    vms = CbrainTask.where(:status => ActiveTasks, :type => "CbrainTask::StartVM")
    #reject vms of offline bourreaux and with wrong disk images
    alive_vms_with_good_disk_image = vms.reject{ |x| !Bourreau.find(x.bourreau_id).is_alive? || (x.params[:disk_image] != self.disk_image_file_id)}
    log_vm "There are #{alive_vms_with_good_disk_image.count} active VMs (including replicas)"
    return alive_vms_with_good_disk_image
  end

  def measure_load vms #:nodoc:
    disk_images = DiskImageBourreau.where(:disk_image_file_id => self.disk_image_file_id)
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

  def get_active_tasks(bourreau_id) #:nodoc:
    return CbrainTask.where(:bourreau_id => bourreau_id,:status => ActiveTasks,:type => "CbrainTask::StartVM").count
  end

  # Abstract method to submit a VM. 
  # Has to determine where to submit and possibly replicate VMs.
  def submit_vm
    raise "Abstract method. Must be implemented by child classes."
  end

  # Helper method to submit and replicate VMs on a set of sites.
  # May be used by derived classes.
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

  # Helper method to submit a VM to a particular Bourreau.
  # May be used by derived classes. 
  def submit_vm_to_site(bourreau_id)
    bourreau = Bourreau.find(bourreau_id)    
    if not bourreau.is_alive? then 
      log_vm  "Refusing".colorize(33) +" to submit VM to #{bourreau.name.colorize(33)} which is not alive" # just in case, this shouldn't happen.
      return nil
    end
    
    log_vm "Submitting a new VM to #{bourreau.name.colorize(33)}"
    task = CbrainTask.const_get("StartVM").new
    task.params = task.class.wrapper_default_launch_args.clone

    # will submit with user associated to the first virtual bourreau we find with this disk image
    disk_image = DiskImageBourreau.where(:disk_image_file_id => self.disk_image_file_id).first
    task.params[:vm_user] = disk_image.disk_image_user 
    task.user = User.where(:login => "admin").first
    task.bourreau_id = bourreau_id
    task.tool_config = ToolConfig.where(:tool_id => @start_vm_tool_id, :bourreau_id => bourreau.id).first
    task.status = "New" 
    task.params[:disk_image] = self.disk_image_file_id
    
    if bourreau.cms_class == "ScirOpenStack" 
      task.params[:open_stack_image_flavor] = DiskImageConfig.where(:bourreau_id => bourreau.id, :disk_image_bourreau_id => disk_image.id).first.open_stack_default_flavor
    end

    task.save!
    Bourreau.find(task.bourreau_id).send_command_start_workers rescue true
    return task
  end

  # Checks if VM factory is still alive. 
  def alive?
    self.timestamp_of_last_iteration.blank? ? false : (Time.now - self.timestamp_of_last_iteration < 3*self.tau)
  end

  # Selects and terminates a VM. 
  # See Algorithm 2 in CCGrid 2014 paper.
  def remove_vm
    return remove_vm_from_site    
  end
  
  # See Algorithm 2 in CCGrid 2014 paper.
  def remove_vm_from_site(bourreau_id = nil) #:nodoc:
    if bourreau_id.blank? then log_vm  "Removing a VM (site selection based on VM statuses)" else log_vm  "Removing a VM from site " + "#{Bourreau.find(bourreau_id).name}".colorize(33) end 
    # get queuing VMs # TODO get only VMs queued for this disk image
    queued_all = bourreau_id.blank? ? CbrainTask.where(:type => "CbrainTask::StartVM", :status => [ 'New','Queued', 'Setting Up'] ) : CbrainTask.where(:type => "CbrainTask::StartVM", :status => [ 'New','Queued', 'Setting Up'], :bourreau_id => bourreau_id )
    queued = queued_all.reject{ |x| x.params[:disk_image] != self.disk_image_file_id || !Bourreau.find(x.bourreau_id).is_alive?}
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
      on_cpu = on_cpu_all.reject{ |x| x.params[:disk_image] != self.disk_image_file_id || !Bourreau.find(x.bourreau_id).is_alive?}
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

  # Terminates a VM.
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

  def get_ids_of_target_bourreaux #:nodoc:
    # Returns the candidate bourreau ids for VM submission.
    Bourreau.where(:online => true).reject{|x| !x.is_alive?}.map {|i| i.id } & ToolConfig.where(:tool_id => @start_vm_tool_id).select(:bourreau_id).map {|i| i.bourreau_id}
  end
  
  def handle_replicas #:nodoc:
    # Handles replicas of OnCPU VMs
    # See algorithm 2 in CCGrid 2014 paper
    on_cpu_all = CbrainTask.where(:type => "CbrainTask::StartVM", :status => [ 'On CPU'] )
    on_cpu = on_cpu_all.reject{ |x| x.params[:disk_image] != self.disk_image_file_id || !Bourreau.find(x.bourreau_id).is_alive?}
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
end  

