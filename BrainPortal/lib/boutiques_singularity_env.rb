
#
# CBRAIN Project
#
# Copyright (C) 2008-2020
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

# To autopropagate all env variable to singularity container this module
# adds "SINGULARITYENV_" prefix to all env variable (e.g. "SINGULARITYENV_ABC")
#
# To include the module automatically at boot time
# in a task integrated by Boutiques, add a new entry
# in the 'custom' section of the descriptor, like this:
#
#   "custom": {
#       "cbrain:integrator_modules": {
#           "BoutiquesSingularityEnv": true
#           }
#       }
#   }
#
module BoutiquesSingularityEnv
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  PREFIX = "SINGULARITYENV_"  # this prefix guaranties that variable gets inside apptainer container
                              # likely to be deprecated soon ( APPTAINERENV_ is the prefix for newer version)

  # adds "SINGULARITYENV_" prefix to all the env variables of the task's tool config
  def ensure_env_prefix(prefix=PREFIX)
    return if self.tool_config.container_engine != "Singularity" # todo update to "Apptainer" one day
    env_array = self.tool_config.env_array
    return if env_array.blank?
    env_array.each do |name_val|
      name, _ = name_val
      unless name.start_with? PREFIX
        name_val[0] = "#{PREFIX}#{name}"
        # to make admin life easier tool_config is modified with new variable names

        msg = "Prefix #{prefix} added to variable #{name} to visibility inside the container"
        self.addlog(msg)
        self.tool_config.addlog(msg)
      end
    end
    self.tool_config.save
  end

  def setup #:nodoc:
    self.ensure_env_prefix
    super
  end

  def before_form #:nodoc:
    self.ensure_env_prefix
    super
  end

end
