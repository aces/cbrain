
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

# Move a file.
class BackgroundActivity::MoveFile < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_bac_presence_of_option         :dest_data_provider_id
  validates_dynamic_bac_presence_of_option :userfile_custom_filter_id

  # Helper for scheduling a move of the files immediately.
  def self.setup!(user_id, userfile_ids, remote_resource_id, dest_data_provider_id, options={})
    ba         = self.local_new(user_id, userfile_ids, remote_resource_id)
    ba.options = options.merge( :dest_data_provider_id => dest_data_provider_id )
    ba.save!
    ba
  end

  def process(item)
    userfile   = Userfile.find(item)
    dest_dp_id = self.options[:dest_data_provider_id]
    dest_dp    = DataProvider.find(dest_dp_id)
    ok         = userfile.provider_move_to_otherprovider(dest_dp, self.options || {})
    message    = ok ? "Moved" : "Failed to move '#{userfile.name}'"
    [ ok, message ]
  end

  def prepare_dynamic_items
    populate_items_from_userfile_custom_filter
  end

end

