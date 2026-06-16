
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

# This module turns on the ability to push a task's outputs
# to a Zenodo deposit. The core functionality is
# already un place within the CBRAIN tasks controller,
# but tasks objects need to be able to provide the IDs of their
# output files for the controller code to work. This module does that.
#
# In the descriptor, the functionality is turned on by
# specifying the ids of the boutiques output-files
# structures, and the files created for them will be
# packaged in the Zenodo deposit. If a boutiques output-file
# produces more than one CBRAIN output file, all of them will be
# pushed.
#
# In the descriptor, add the BoutiquesZenodoPusher configuration
# information into the 'custom' -> 'cbrain:integrator_modules' section.
#
#   "custom": {
#       "cbrain:integrator_modules": {
#           "BoutiquesZenodoPusher": {
#             "my_output1": true,
#             "my_output2": true,
#           }
#       }
#   }
#
module BoutiquesZenodoPusher

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def zenodo_outputfile_ids # this is a PortalTask method that is needed to turn on Zenodo
    descriptor      = self.boutiques_descriptor
    outputs_to_push = descriptor.custom_module_info('BoutiquesZenodoPusher') || {}

    zenodo_userfile_ids = [] # the full list we prepare here

    outputs_to_push.each do |outputid, enabled|
      next unless enabled.present?
      output_file_ids = self.params["_cbrain_output_#{outputid}"] # typically an array of userfile IDs
      next if output_file_ids.blank?
      output_file_ids = Userfile.where(:id => output_file_ids).pluck(:id) # filter out missing files
      zenodo_userfile_ids |= output_file_ids
    end

    return zenodo_userfile_ids
  end

end
