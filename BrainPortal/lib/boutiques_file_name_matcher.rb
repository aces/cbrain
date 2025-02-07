
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
# names of files selected in a File input of a Boutiques Task.
#
# To include the module automatically at boot time
# in a task integrated by Boutiques, add a new entry
# in the 'custom' section of the descriptor, like this:
#
#   "custom": {
#       "cbrain:integrator_modules": {
#           "BoutiquesFileNameMatcher": {
#             "my_input": "^sub-[a-zA-Z0-9]*$"
#           }
#       }
#   }
#
# In the example above, any userfile selected for the file input
# named 'my_input' will be validated to make sure its name matches
# the regular expression /^sub-[a-zA-Z0-9]*$/
module BoutiquesFileNameMatcher

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def after_form #:nodoc:
    descriptor = self.descriptor_for_after_form
    verifs     = descriptor.custom_module_info('BoutiquesFileNameMatcher') || []

    verifs.each do |inputid,regexstring| # 'myinput' => "^sub-[a-zA-Z0-9]*$"
      input = descriptor.input_by_id(inputid)
      regex = Regexp.new(regexstring)
      #puts_red "In=#{inputid} Regex=#{regex.inspect}"
      found_match = Array(invoke_params[inputid])
        .map(&:presence)
        .compact
        .all? do |userfileid|
          file = Userfile.find(userfileid)
          file.is_a?(CbrainFileList) || file.name.match(regex) # we don't validate the names of CbrainFileLists
        end
      if ! found_match
        params_errors.add(input.cb_invoke_name, "does not have a proper name (should match #{regex.inspect})")
      end
    end

    super # call all the normal code
  end

end
