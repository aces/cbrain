
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

class CbrainTask::StartVM #:nodoc:
  
  def param_validation_errors #:nodoc:
    errors = Hash.new

    errors[:disk_image]         = "Missing disk image."                                               unless params[:disk_image].presence
    errors[:vm_user]            = "Missing VM user."                                                  unless params[:vm_user].presence   
    errors[:ssh_key_pair]       = "Missing ssh key pair."                                             unless params[:ssh_key_pair].presence
    errors[:instance_type]      = "Missing cloud instance type."                                      unless params[:instance_type].presence
    errors[:job_slots]          = "Missing number of job slots."                                      unless params[:job_slots].presence
    errors[:job_slots]          = "Number of job slots has to be an integer."                         unless is_integer? params[:job_slots]
    errors[:vm_boot_timeout]    = "Missing VM boot timeout."                                          unless params[:vm_boot_timeout].presence
    errors[:vm_boot_timeout]    = "Boot timeout has to be an integer."                                unless is_integer? params[:vm_boot_timeout]
    errors[:vm_ssh_tunnel_port] = "Missing ssh tunnel port."                                          unless params[:vm_ssh_tunnel_port].presence
    errors[:vm_ssh_tunnel_port] = "ssh tunnel port has to be an integer."                             unless is_integer? params[:vm_ssh_tunnel_port]
    errors[:number_of_vms]      = "Missing number of instances."                                      unless params[:number_of_vms].presence
    errors[:number_of_vms]      = "Number of instances has to be an integer."                         unless is_integer? params[:number_of_vms]
    errors[:number_of_vms]      = "Please don't try to start more than 20 instances at once."         if params[:number_of_vms].to_i > 20

    return errors
  end

  def is_integer?(a) #:nodoc:
    return true if a.is_a?(Integer)
    return true if a.is_an_integer? # added to class String in utilities
    return false
  rescue => ex # reached when a is not an Integer and it's not a String
    return false
  end

  def is_float?(a) #:nodoc:
    return true if a.is_a?(Numeric)
    return true if a.is_a_float? # added to class String in utilities
    return false
  rescue => ex # reached when a is not a Numeric and it's not a String
    return false
  end
end
