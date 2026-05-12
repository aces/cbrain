
#
# CBRAIN Project
#
# Copyright (C) 2008-2026
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

#
# This module provides a tool with the ability to selectively specify resources parameters (walltime, cpus, memory)
# based on the values of some of the input fields.
#
#
# For example an input with specific value:
#   "BoutiquesResourceManager": {
#      "step": {
#         "demuxalot":
#         {
#             "cpu-cores":         6,
#             "ram":               15,
#             "walltime-estimate": "02:00:00"
#         },
#         "demuxlet":
#         {
#             "cpu-cores":         1,
#             "ram":               150,
#             "walltime-estimate": "04:00:00"
#         }
#      }
#   }
#
# If step input is selected with:
#     - demuxalot it will set the ram requirement to 15
#     - demuxlet  it will set the ram requirement to 150
#
# It can be used for input that accept a boolean:
#   "BoutiquesResourceManager": {
#      "vireo": {
#         "true":
#         {
#             "cpu-cores":         1,
#             "ram":               30,
#             "walltime-estimate": "01:00:00"
#         }
#      }
#   }
#
# If multiple option are setup the highest value needed for cpu-core and ram will be kept,
# and all walltime requirement will be added.
#
module BoutiquesResourceManager

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def job_walltime_estimate #:nodoc:
    @_custom_asked_resources ||= asked_resources()

    asked_walltimes = @_custom_asked_resources.map do |resources|
      walltime_in_seconds(resources["walltime-estimate"])
    end.reject { |x| x == 0 }

    walltime_estimate = asked_walltimes.empty? ? super : asked_walltimes.sum
    self.addlog("walltime: #{walltime_estimate.inspect}")
    return walltime_estimate
  end

  def job_memory_estimate #:nodoc:
    @_custom_asked_resources ||= asked_resources()

    asked_memories = @_custom_asked_resources.map do |resources|
      resources["ram"].to_i # in GB
    end.compact.reject { |x| x == 0 }

    return super if asked_memories.empty?
    memory_estimate = asked_memories.max  # in GB
    self.addlog("memory: #{memory_estimate} GB")
    return(memory_estimate * 1024) # in MB
  end

  def job_number_of_cores #:nodoc:
    @_custom_asked_resources ||= asked_resources()

    asked_cpus = @_custom_asked_resources.map do |resources|
      resources["cpu-cores"].to_i rescue nil
    end.compact.reject { |x| x == 0 }

    number_of_cores = asked_cpus.empty?  ? super : asked_cpus.max
    self.addlog("cpu-cores: #{number_of_cores.inspect}")
    return number_of_cores
  end

  def asked_resources #:nodoc:
    descriptor              = self.descriptor_for_cluster_commands
    resource_manager_config = descriptor.custom_module_info('BoutiquesResourceManager') || {}

    resource_manager_config.map do |input_id, resources|
      # Extract value
      input = descriptor.input_by_id(input_id)
      val   = self.invoke_params[input_id]

      # Various check (todo: add ajustement by size if needed)
      val   = false if input.type == "Flag" && val.nil?

      # Final lookup of resources structure
      val   = val.to_s
      res   = resources[val] # {"cpu-cores": 6, "ram": 40, "walltime-estimate": "2-4:00:00" }
      res
    end.compact
  end

  private

  def walltime_in_seconds(walltime) #:nodoc:
    # nil or already in second
    return 0             if !walltime
    return walltime      if walltime.is_a?(Integer)
    return walltime.to_i if walltime =~ /\A\d+\z/

    # Should be in format "DD-HH:MM:SS" of "HH:MM:SS" other cb_error
    unless walltime =~ /\A(?:(\d+)-)?([0-1]\d|2[0-3]):([0-5]\d):([0-5]\d)$\z/
      cb_error "Invalid walltime format '#{walltime.inspect}': expected DD-HH:MM:SS or HH:MM:SS"
    end

    days, hours, minutes, seconds = Regexp.last_match.to_a[1..4].map { |v| v.to_i }

    return days * 86400 + hours * 3600 + minutes * 60 + seconds
  end

end
