
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

# This module adds automatic verification of the
# type of files selected in a File input of a Boutiques Task.
#
# To include the module automatically at boot time
# in a task integrated by Boutiques, add a new entry
# in the 'custom' section of the descriptor, like this:
#
#   "custom": {
#       "cbrain:integrator_modules": {
#           "BoutiquesFileTypeVerifier": {
#             "my_input": [ "TextFile", "MincFile" ]
#           }
#       }
#   }
#
# In the example above, any userfile selected for the file input
# named 'my_input' will be validated to make sure it respond to
# is_a?() for one of the types in the list.
module BoutiquesFileTypeVerifier

  def after_form #:nodoc:
    descriptor = self.descriptor_for_before_form
    verifs     = descriptor.custom_module_info('BoutiquesFileTypeVerifier')

    verifs.each do |inputid,typenames| # 'myinput' => [ 'TextFile', 'MincFile' ]
      input = descriptor.input_by_id(inputid)
      #puts_red "In=#{inputid} Types=#{typenames.inspect}"
      types = typenames.map(&:constantize)
      found_match = Array(invoke_params[inputid])
        .map(&:presence)
        .compact
        .all? do |userfileid|
          file = Userfile.find(userfileid)
          types.any? { |type| file.is_a?(type) }
        end
      if ! found_match
        params_errors.add(input.cb_invoke_name, "is not of the proper type (should be #{typenames.join(",")})")
      end
    end

    super # call all the normal code
  end

end
