
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

# Destroy files that are not even registered.
# Basenames are provided as an items list.
class BackgroundActivity::DestroyUnregisteredFile < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def pretty_name
    cnt         = self.items.size
    source_name = DataProvider.where(:id => self.options[:src_data_provider_id]).first&.name || "Unknown"
    "Destroy #{cnt} unregistered file#{cnt > 1 ? 's' : ''} on #{source_name}"
  end

  # Helper for scheduling a destruction of unregistered files immediately.
  def self.setup!(user_id, basenames, remote_resource_id, src_data_provider_id, browse_path)
    ba         = self.local_new(user_id, basenames, remote_resource_id)
    ba.options = {
      :src_data_provider_id => src_data_provider_id,
      :browse_path          => browse_path,
    }
    ba.save!
    ba
  end

  def process(item)  # item is a basename like "abcd.xyz"
    src_dp_id   = self.options[:src_data_provider_id]
    browse_path = self.options[:browse_path].presence
    dp          = DataProvider.find(src_dp_id)
    user        = User.admin
    group       = user.own_group

    temporary   = FileCollection.new(
      :name             => item,
      :user_id          => user.id,
      :group_id         => group.id,
      :data_provider_id => dp.id,
      :browse_path      => browse_path,
    ).fake_record!

    result = dp.provider_erase(temporary)
    [ result, nil ] # no messages ever
  end

end

