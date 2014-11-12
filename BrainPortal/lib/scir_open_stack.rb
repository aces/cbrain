
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

# This is a replacement for the drmaa.rb library; this particular subclass
# of class Scir implements a dummy cluster interface that still runs
# jobs locally as standard unix subprocesses.


require 'openstack'

# A Scir class to handle VMs on OpenStack clouds (see https://www.openstack.org).
# This class can only handle tasks of type CBRAIN::StartVM.

class ScirOpenStack < ScirCloud

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def get_available_instance_types 
    os = get_open_stack_connection   
    instance_types =  Array.new
    os.list_flavors.each do |flavor|
      instance_types << [ flavor[:name].to_s , flavor[:id].to_s]
    end
  end

  # Inner Session class 
  class Session < Scir::Session #:nodoc:

    def update_job_info_cache #:nodoc:
      @job_info_cache = {}
      os = get_open_stack_connection()
      os.servers.each do |s|
        # get status
        state = statestring_to_stateconst(os.server(s[:id]).status)
        if state == "ERROR"
          os.server(s[:id]).delete!
        end
        @job_info_cache[s[:id].to_s] = { :drmaa_state => state }
      end
      true
    end

    def statestring_to_stateconst(state) #:nodoc:
      return Scir::STATE_RUNNING        if state == "ACTIVE"
      return Scir::STATE_QUEUED_ACTIVE  if state == "BUILD"
      return Scir::STATE_FAILED         if state == "ERROR"
      return Scir::STATE_UNDETERMINED
    end

    def hold(jid)
      true
    end

    def release(jid)
      true
    end

    def suspend(jid)
      # OpenStack Ruby API doesn't seem to be able to pause intances
      return true
    end

    def resume(jid)
      # OpenStack Ruby API doesn't seem to be able to pause/start intances
      return true
    end

    def terminate(jid)
      os = get_open_stack_connection()
      os.server(jid).delete!
    end
    
    def get_local_ip(jid)
      cluster_jobid = CbrainTask.where(:id => jid).first.cluster_jobid
      os = get_open_stack_connection()
      return os.server(cluster_jobid).accessipv4
    end

    def queue_tasks_tot_max
      loadav = `uptime`.strip
      loadav.match(/averages?:\s*([\d\.]+)/i)
      loadtxt = Regexp.last_match[1] || "unknown"
      case CBRAIN::System_Uname
      when /Linux/i
        cpuinfo = `cat /proc/cpuinfo 2>&1`.split("\n")
        proclines = cpuinfo.select { |i| i.match(/^processor\s*:\s*/i) }
        return [ loadtxt , proclines.size.to_s ]
      when /Darwin/i
        hostinfo = `hostinfo 2>&1`.strip
        hostinfo.match(/^(\d+) processors are/)
        numproc = Regexp.last_match[1] || "unknown"
        [ loadtxt, numproc ]
      else
        [ "unknown", "unknown" ]
      end
    rescue => e
      [ "exception", "exception" ]
    end

    def get_open_stack_connection()
      username = Scir.cbrain_config[:open_stack_user_name]
      password = Scir.cbrain_config[:open_stack_password]
      auth_url = Scir.cbrain_config[:open_stack_auth_url]
      tenant_name = Scir.cbrain_config[:open_stack_tenant]  
      os = OpenStack::Connection.create({:username => username, :api_key=> password, :auth_method=>"password", :auth_url => auth_url, :authtenant_name =>tenant_name, :service_type=>"compute"})
    end

    def submit_VM(vm_name,image_id,flavor_ref)
      os = get_open_stack_connection()
      image = os.get_image(image_id)
      new_server = os.create_server(:name => vm_name , :imageRef => image.id, :flavorRef => flavor_ref)
    end
    
    def run(job)
      task = CbrainTask.find(job.task_id)
      disk_image_bourreaux = Bourreau.where(:disk_image_file_id => task.params[:disk_image])
      image_id = nil
      disk_image_bourreaux.each do |b|
      	image_id = DiskImageConfig.where(:disk_image_bourreau_id => b.id, :bourreau_id => RemoteResource.current_resource.id).first.open_stack_disk_image_id
      end
      raise "Cannot find Disk Image Bourreau associated with file id #{task.params[:disk_image]} or Disk Image Bourreau has no OpenStack image id for #{RemoteResource.current_resource.name}" unless !image_id.blank?
      vm = submit_VM("CBRAIN Worker", image_id, task.params[:instance_type]) 
      return vm.id.to_s
    end

    private

    def qsubout_to_jid(txt)
      raise "Not used in this implementation."
    end

  end
  
  # This method seems required
  class JobTemplate < Scir::JobTemplate #:nodoc
    # NOTE: We use a custom 'run' method in the Session, instead of Scir's version.
    def qsub_command
      return "blah"
    end
    
  end

end

