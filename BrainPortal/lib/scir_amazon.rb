
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

require 'aws-sdk'

# A ScirCloud class to handle VMs on Amazon EC2. 
# This type of Scir can only handle tasks of type CBRAIN::StartVM.
class ScirAmazon < ScirCloud
 
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Overrides the abstract method defined in ScirCloud.  
  def self.get_available_instance_types(bourreau)
    # no, there's no method in the API to return such an array!
    # yes, the available instance types change over time!
    return [ "t2.micro","t1.micro","m1.small","m1.medium","m1.large","m1.xlarge",
    "m3.medium","m3.large","m3.xlarge","m3.2xlarge","m4.large","m4.xlarge",
    "m4.2xlarge","m4.4xlarge","m4.10xlarge","t2.nano","t2.small","t2.medium",
    "t2.large","m2.xlarge","m2.2xlarge","m2.4xlarge","cr1.8xlarge","i2.xlarge",
    "i2.2xlarge","i2.4xlarge","i2.8xlarge","hi1.4xlarge","hs1.8xlarge","c1.medium",
    "c1.xlarge","c3.large","c3.xlarge","c3.2xlarge","c3.4xlarge","c3.8xlarge",
    "c4.large","c4.xlarge","c4.2xlarge","c4.4xlarge","c4.8xlarge","cc1.4xlarge",
    "cc2.8xlarge","g2.2xlarge","g2.8xlarge","cg1.4xlarge","r3.large","r3.xlarge",
    "r3.2xlarge","r3.4xlarge","r3.8xlarge","d2.xlarge","d2.2xlarge","d2.4xlarge","d2.8xlarge" ]
  end

  # Overrides the abstract method defined in ScirCloud.
  def self.get_available_disk_images(bourreau)
    images = Array.new
    ec2 = get_amazon_ec2_connection(bourreau.meta[:amazon_ec2_access_key_id],
                                    bourreau.meta[:amazon_ec2_secret_access_key],
                                    bourreau.meta[:amazon_ec2_region])
    ec2.describe_images(owners: [ "self" ]).images.each { |image| images << [image.name,image.image_id] }
    return images
  end

  # Overrides the abstract method defined in ScirCloud
  def self.get_available_key_pairs(bourreau)
    ec2 = get_amazon_ec2_connection(bourreau.meta[:amazon_ec2_access_key_id],
                                    bourreau.meta[:amazon_ec2_secret_access_key],
                                    bourreau.meta[:amazon_ec2_region])
    keys = []
    ec2.describe_key_pairs.key_pairs.each { |key| keys << [key.key_name] }
    return keys
  end

  private

  # Returns an Aws::EC2::Client object connected with the corresponding properties.
  # * access_key_id: a string containing the access key id as configured in the Amazon account (see 'IAM' service).
  # * secret_access_key: a string containing the secret access key as configured in the Amazon account (see 'IAM' service).
  # * amazon_ec2_region: a string containing the Amazon region to use, e.g. "us-west-1".
  def self.get_amazon_ec2_connection(access_key_id, secret_access_key, amazon_ec2_region)
    ec2 = Aws::EC2::Client.new(access_key_id: access_key_id,
                               secret_access_key: secret_access_key,
                               region: amazon_ec2_region)
    return ec2
  end
  
  class Session < ScirCloud::Session #:nodoc:

    @@state_if_missing = Scir::STATE_RUNNING

    # Returns the local IP address of the VM associated to the
    # CBRAIN task with id 'jid'.
    def get_local_ip(jid)
      return get_instance_from_cbrain_job_id(jid).private_ip_address
    end

    # Overrides the default Scir method.
    def update_job_info_cache #:nodoc:
      @job_info_cache = {}
      ec2 = get_amazon_ec2_connection
      ec2.describe_instance_status.instance_statuses.each do |instance_status|
        state = statestring_to_stateconst(instance_status.instance_state.name)
        @job_info_cache[instance_status.instance_id.to_s] = { :drmaa_state => state }
      end
      true
    end

    # Convert an Amazon state string to a Scir status.
    def statestring_to_stateconst(state) #:nodoc:
      return Scir::STATE_RUNNING        if state == "running"
      return Scir::STATE_DONE           if state == "stopped"
      return Scir::STATE_QUEUED_ACTIVE  if state == "pending"
      return Scir::STATE_FAILED         if state == "terminated"
      return Scir::STATE_UNDETERMINED
    end

    # Terminates the VM.
    def terminate_vm(jid)      
      ec2 = get_amazon_ec2_connection
      ec2.terminate_instances({:instance_ids => [ jid ]})
    end

    private

    # A utility method to get the Amazon EC2 connection from the Scir
    # configuration parameters.
    def get_amazon_ec2_connection
      return ScirAmazon.get_amazon_ec2_connection(
               Scir.cbrain_config[:amazon_ec2_access_key_id],
               Scir.cbrain_config[:amazon_ec2_secret_access_key],
               Scir.cbrain_config[:amazon_ec2_region])
    end

    # Submits a VM to Amazon EC2.
    # Parameters:
    # * vm_name: name of the VM to create (currently ignored)
    # * image_id: image id used by the VM
    # * key_name: ssh key name that will be authorized in the VM
    # * instance_type: instance type used by the VM
    # * tag_value: a string used to tag the VM
    def submit_vm(vm_name,image_id,key_name,instance_type,tag_value)
      ec2 = get_amazon_ec2_connection
      
      # Finds the cbrain security group, or creates it if it doesn't exit.
      cbrain_security_group_name="cbrain worker"
      if(ec2.describe_security_groups.security_groups.detect{|g| g.group_name == cbrain_security_group_name}.nil?)
        ec2.create_security_group({
                                    :group_name => cbrain_security_group_name,
                                    :description => "Security group for CBRAIN workers"})
        
        ec2.authorize_security_group_ingress({ # authorize incoming ssh connections, from any source
                                               :group_name => cbrain_security_group_name,
                                               :ip_permissions => [ { 
                                                                      :ip_protocol => "tcp",
                                                                      :from_port => 22,
                                                                      :to_port => 22,
                                                                      :ip_ranges => [ :cidr_ip => "0.0.0.0/0" ]
                                                                    } ]
                                             })
      end
      
      # Submits the instance
      resp = ec2.run_instances({
                                 :image_id => image_id,
                                 :instance_type => instance_type,
                                 :key_name => key_name,
                                 :security_groups => [cbrain_security_group_name],
                                 :min_count => 1,
                                 :max_count => 1
                               })
      raise "Submitted 1 VM instance but obtained #{resp.instances.length} objects." if(resp.instances.length !=1)

      # Tags the instance
      instance = resp.instances[0]
      (1..30).each do |i| # poor man's timer
        begin
          # may raise an exception
          ec2.create_tags({
                            :resources => [ instance.instance_id ],
                            :tags => [ { :key => "Service" , :value => tag_value } ]
                          })
          break
        rescue => e
          nil
        end
        sleep 1
      end
      return instance
      # Note: vm_name is not used. Although we can change an instance
      # name through the EC2 web portal, it doesn't look like there is
      # an API method to do this.
    end

    # Returns the VM instance associated to the CBRAIN task with id
    # 'jid'.
    def get_instance_from_cbrain_job_id(jid)
      cluster_jobid = CbrainTask.where(:id => jid).first.cluster_jobid
      return get_vm_instance(cluster_jobid)
    end

    # Returns the VM instance with Amazon id 'id'.
    def get_vm_instance(id)
      ec2 = get_amazon_ec2_connection
      ec2.describe_instances.reservations.each do |r| 
        r.instances.each do |x|
          return x if x.instance_id == id
        end
      end
      return nil
    end
    
  end

end

