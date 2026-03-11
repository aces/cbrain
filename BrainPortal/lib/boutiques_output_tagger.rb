
#
# CBRAIN Project
#
# Copyright (C) 2008-2025
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

# This module adds automatic setting of a set of tags
# to a file output of a Boutiques Task.
#
# To include the module automatically at boot time
# in a task integrated by Boutiques, add a new entry
# in the 'custom' section of the descriptor, like this:
#
#   "custom": {
#       "cbrain:integrator_modules": {
#           "BoutiquesOutputTagger": {
#             "my_output1": [ "tagname1", "tagname2" ],
#             "my_output2": [ "tagname1", "tagname3" ]
#           }
#       }
#   }
#
module BoutiquesOutputTagger

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def save_results
    return false unless super

    # Find the config for this module
    desc = self.descriptor_for_save_results
    tag_struct = desc.custom_module_info('BoutiquesOutputTagger') || {}
    return true if tag_struct.empty?

    # Found all outputs and tag them
    tag_struct.each do |output_id,taglist|
      file_ids = Array(self.params["_cbrain_output_#{output_id}"])
      file_ids.each do |fid|
        userfile = Userfile.where(:id => fid).first
        if ! userfile
          self.addlog("BoutiquesOutputTagger: Skipped tagging file ##{fid} for output '#{output_id}': file doesn't exist.")
          next
        end
        tag_ids = taglist.map do |tagname|
          tag_req = Tag.where(:name => tagname, :group_id => self.group_id) # scope is one tag name per prject
          tag = tag_req.first
          if ! tag
             self.addlog "BoutiquesOutputTagger: Creating new tag '#{tagname}'"
             tag_req = tag_req.where(:user_id => self.user_id)  # add owner
             tag = tag_req.create!
          end
          tag.id
        end
        self.addlog "BoutiquesOutputTagger: tagging file '#{userfile.name}' (ID #{userfile.id}) with tags: #{taglist.join(', ')}"
        userfile.tag_ids |= tag_ids
      end
    end

    return true
  end

end
