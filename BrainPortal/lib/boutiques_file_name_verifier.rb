
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
# files (or directories ) names generated as output to prevent injection.
#
# For exmaple, in the "inputs" section:
#
#   {
#     "description": "The name of the folder to store outputs of XCPD processing.",
#     "id": "output_dir",
#     "name": "output_dir",
#     "optional": false,
#     "type": "String",
#     "value-key": "[OUTPUT_DIR]",
#     "default-value": "xcpd_output"
#   }
# and in the "output-files" section:
#
#   {
#     "name": "XCPD Subject Output Directory",
#     "id":  "xcpd_output_dir",
#     "description": "Subject level output for XCP-D",
#     "optional":  false,
#     "path-template": "[OUTPUT_DIR]"
#   }
# The prevent problems, right from the start before launching a task, we should validate
# them a little bit and make sure they respect the rules that CBRAIN impose for userfiles.
#
# "cbrain:integrator_modules": {
#   "BoutiquesOutputNameValidator": [ "output_dir", "other_id", "other_id_2" ]
# }
module BoutiquesFileTypeVerifier

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def after_form #:nodoc:
    descriptor = self.descriptor_for_after_form
    verifs     = descriptor.custom_module_info('BoutiquesFileNameVerifier')

    verifs.each do |inputid| # 'myinput'
      input = descriptor.input_by_id(inputid)
      found_match = Array(invoke_params[inputid])
        .map(&:presence)
        .compact
        .all? do |fname|
          Userfile.is_legal_filename?(fname)
        end
      if ! found_match
        # "file names should us printable characters only, with no slashes ASCII nulls,
        # and they must start with a letter or digit"
        params_errors.add(input.cb_invoke_name, "is not of the proper name for file (or directory), avoid hyphens or other special symbols")
      end
    end

    super # call all the normal code
  end

end
