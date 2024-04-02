
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

# Tracks a background activity job
class BackgroundActivity::RegisterAndCopyFile < BackgroundActivity::RegisterFile

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def pretty_name
    cnt         = self.items.size
    source_name = DataProvider.where(:id => self.options[:src_data_provider_id]).first&.name || "Unknown"
    dest_name   = DataProvider.where(:id => self.options[:dest_data_provider_id]).first&.name || "Unknown"
    "Register #{cnt} file#{cnt > 1 ? 's' : ''} on #{source_name} and copy to #{dest_name}"
  end

  # Helper for scheduling a registration and copy of the files immediately.
  def self.setup!(user_id, type_dash_names, remote_resource_id, src_data_provider_id, browse_path, group_id, as_user_id, dest_data_provider_id)
    ba         = self.local_new(user_id, type_dash_names, remote_resource_id)
    ba.options = {
      :src_data_provider_id    => src_data_provider_id,
      :browse_path             => browse_path,
      :as_user_id              => (as_user_id || user_id),
      :group_id                => group_id,
      :dest_data_provider_id   => dest_data_provider_id,
    }
    ba.save!
    ba
  end

  def process(item)  # item is like "TextFile-abcd.xyz"
    ok, userfile_id = super # userfile_id is an error message if ok is false
    return [ ok, userfile_id ] if ! ok # registration failed
    dest_dp_id  = self.options[:dest_data_provider_id]
    userfile    = Userfile.find(userfile_id)
    dest_dp     = DataProvider.find(dest_dp_id)
    newfile     = userfile.provider_copy_to_otherprovider(dest_dp)
    userfile.keep_dp_content_on_destroy = true
    userfile.destroy
    [ true, newfile.id ]
  end

end

