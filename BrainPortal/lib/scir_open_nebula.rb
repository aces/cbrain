
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
#
# Original author: Tristan Glatard
require 'openstack'

class ScirOpenNebula < Scir

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  class Session < Scir::Session #:nodoc:

    def update_job_info_cache
      @job_info_cache = {}
      os = get_open_stack_connection("tglatard", "PowchEdip0","http://204.19.23.16:5000/v2.0", "cbrain")
      os.servers.each do |s|
        # get status
        state = statestring_to_stateconst(os.server(s[:id]).status)
        @job_info_cache[s[:id].to_s] = { :drmaa_state => state }
      end
      true
    end

    def statestring_to_stateconst(state)
      return Scir::STATE_RUNNING        if state == "ACTIVE"
      return Scir::STATE_QUEUED_ACTIVE  if state == "BUILD"
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
      os = get_open_stack_connection("tglatard", "PowchEdip0","http://204.19.23.16:5000/v2.0", "cbrain")
      os.server(jid).delete!
    end
    
    def get_local_ip(jid)
      cluster_jobid = CbrainTask.where(:id => jid).first.cluster_jobid
      os = get_open_stack_connection("tglatard", "PowchEdip0","http://204.19.23.16:5000/v2.0", "cbrain")
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

    def get_open_stack_connection(username, password,auth_url,tenant_name)
      os = OpenStack::Connection.create({:username => username, :api_key=> password, :auth_method=>"password", :auth_url => auth_url, :authtenant_name =>tenant_name, :service_type=>"compute"})
    end

    def submit_VM(username, password,auth_url,vm_name,tenant_name,image_id,flavor_ref)
      os = get_open_stack_connection(username, password,auth_url,tenant_name)
      image = os.get_image(image_id)
      new_server = os.create_server(:name => vm_name , :imageRef => image.id, :flavorRef => flavor_ref)
    end
    
    def run(job)

      # TODO (Tristan VM) get instance id and flavor from disk image
      vm = submit_VM("tglatard","PowchEdip0","http://204.19.23.16:5000/v2.0", "cbrain worker", "cbrain", "ec6b6cce-b7d1-425f-8407-d247b01dd7af", "http://204.19.23.16:8774/v2/9dd2bfba6bf040ad83e5140508aa31f0/flavors/0f1f9ac6-8156-4d27-8020-670833f264e8")
      return vm.id.to_s
    end

    private

    def qsubout_to_jid(txt)
      raise "Not used in this implementation."
    end

  end
  
  # This method seems required
  class JobTemplate < Scir::JobTemplate #:nodoc:
    
    # NOTE: We use a custom 'run' method in the Session, instead of Scir's version.
    def qsub_command
      return "blah"
    end
    
  end

end

