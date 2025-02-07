
#
# CBRAIN Project
#
# Copyright (C) 2008-2023
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

# This module adds automatic setting up of mounted
# ext3 filesystem as subdirectories of a task, provided
# the tool works in Singularity/Apptainer.
# It is the exact equivalent of adding an ext3 overlay
# configuration entry in the task's tool config.
#
# To include the module automatically at boot time
# in a task integrated by Boutiques, add a new entry
# in the 'custom' section of the descriptor, like this:
#
#   "custom": {
#       "cbrain:integrator_modules": {
#           "BoutiquesExt3Capturer": {
#             "work":   "50g",
#             "tmpdir": "20m"
#           }
#       }
#   }
#
module BoutiquesExt3Capturer

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Override the default behavior by adding new entries directly
  # from the descriptor.
  def ext3capture_basenames
    # Get standard list as described in tool config
    initial_list = super.dup # [ [ basename, size], [basename, size], ... ]

    # Get values in descriptor, as a hash
    descriptor = self.descriptor_for_cluster_commands
    ext3_specs = descriptor.custom_module_info('BoutiquesExt3Capturer') || {}

    # Append our own entries; note that duplications of basenames
    # will mean only the first entry is used!
    initial_list + ext3_specs.to_a  # the .to_a transforms the hash into an array of pairs.
  end

end

