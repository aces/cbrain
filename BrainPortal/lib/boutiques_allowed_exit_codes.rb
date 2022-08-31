
#
# CBRAIN Project
#
# Copyright (C) 2008-2022
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

# This module allows a Boutiques task to be considered
# succesful even when the command's return code is
# something other than zero.
#
# To include the module automatically at boot time
# in a task integrated by Boutiques, add a new entry
# in the 'custom' section of the descriptor, like this:
#
#   "custom": {
#       "cbrain:integrator_modules": {
#           "BoutiquesAllowedExitCodes": [ 0, 1 ]
#       }
#   }
#
# In the example above, 0 and 1 are both considered
# successful.
module BoutiquesAllowedExitCodes

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # This method overrides the one in BoutiquesClusterTask
  def exit_status_means_failure?(status)

    # Get the acceptable status codes.
    descriptor = self.descriptor_for_save_results
    ok_codes   = descriptor.custom_module_info('BoutiquesAllowedExitCodes')

    addlog("BoutiquesAllowedExitCodes rev. #{Revision_info.short_commit}, status=#{status}, allowed=#{ok_codes}")

    ! Array(ok_codes).include?(status)
  end

end
