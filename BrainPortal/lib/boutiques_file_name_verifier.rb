
#
# CBRAIN Project
#
# Copyright (C) 2008-2024
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

# This module offers automatic verification of the
# files (or directories) names generated as tool output, and therefore have comply with CBRAIN file name conventions.
#
# For example, in the "inputs" section we might have:
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
#
# And the custom property is specified like
#
#   "cbrain:integrator_modules": {
#     "BoutiquesFileNameVerifier": [
#       "output_dir",
#       "another_id"
#     ]
#   }
module BoutiquesFileNameVerifier

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def after_form #:nodoc:
    descriptor = self.descriptor_for_after_form
    verifs     = descriptor.custom_module_info('BoutiquesFileNameVerifier') || []
    verifs.each do |inputid| # 'myinput'
      found_match = Array(invoke_params[inputid])
        .map(&:presence)
        .compact
        .all? do |fname|
          Userfile.is_legal_filename?(fname)
        end
      if ! found_match
        input = descriptor.input_by_id(inputid)
        params_errors.add(input.cb_invoke_name, "is not suitable for naming an output file. Please, change to a value that starts with a letter or number and avoid special or unprintable symbols")
      end
    end

    super # call all the normal code
  end

end
