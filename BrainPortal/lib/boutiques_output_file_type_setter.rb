
#
# CBRAIN Project
#
# Copyright (C) 2008-2021
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

# This module adds automatic setting of the type
# type of a file output of a Boutiques Task.
#
# To include the module automatically at boot time
# in a task integrated by Boutiques, add a new entry
# in the 'custom' section of the descriptor, like this:
#
#   "custom": {
#       "cbrain:integrator_modules": {
#           "BoutiquesOutputFileTypeSetter": {
#             "my_output1": "TextFile",
#             "my_output2": "FileCollection"
#           }
#       }
#   }
#
module BoutiquesOutputFileTypeSetter

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # This method overrides the one in BoutiquesClusterTask
  def name_and_type_for_output_file(output, pathname) #:nodoc:
    name, userfile_class = super  # original suggestions

    # Get the suggestion from the descriptor
    descriptor           = self.descriptor_for_save_results
    out_classes          = descriptor.custom_module_info('BoutiquesOutputFileTypeSetter')
    suggested_class_name = out_classes[output.id]
    return [ name, userfile_class ] if suggested_class_name.blank?

    # Verify it's compatible (e.g. within each of SingleFile or FileCollection subclass branches)
    # Find the top parent of the original class suggestion
    top_class       = (userfile_class <= SingleFile) ? SingleFile : FileCollection
    suggested_class = suggested_class_name.constantize
    return [ name, userfile_class ] if ! (suggested_class <= top_class)

    # Ok, so we apply the new class proposed in the descriptor
    [ name, suggested_class ]
  end

end
