
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

# Register files on a browsable DataProvider
class BackgroundActivity::RegisterFile < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def pretty_name
    cnt         = self.items.size
    source_name = DataProvider.where(:id => self.options[:src_data_provider_id]).first&.name || "Unknown"
    "Register #{cnt} file#{cnt > 1 ? 's' : ''} on #{source_name}"
  end

  # Helper for scheduling a registration of the files immediately.
  def self.setup!(user_id, type_dash_names, remote_resource_id, src_data_provider_id, browse_path, group_id, as_user_id)
    ba         = self.local_new(user_id, type_dash_names, remote_resource_id)
    ba.options = {
      :src_data_provider_id => src_data_provider_id,
      :browse_path             => browse_path,
      :as_user_id              => (as_user_id || user_id),
      :group_id                => group_id,
    }
    ba.save!
    ba
  end

  def process(item)  # item is like "TextFile-abcd.xyz"
    type,name   = item.split("-",2)
    src_dp_id   = self.options[:src_data_provider_id]
    browse_path = self.options[:browse_path].presence
    group_id    = self.options[:group_id]
    as_user_id  = self.options[:as_user_id] || self.user_id
    immutable   = self.options[:immutable].present?
    user        = User.find(self.user_id)
    as_user     = User.find(as_user_id)
    dp          = DataProvider.find(src_dp_id)
    userfile    = Userfile.new(
      :type             => type,
      :name             => name,
      :user_id          => as_user_id,
      :group_id         => group_id,
      :data_provider_id => src_dp_id,
      :browse_path      => browse_path,
      :immutable        => immutable,
    )
    if ! userfile.save
      return [ false, userfile.errors.full_messages.sort.join(", ") ]
    end
    userfile.addlog "Registered on Data Provider '#{dp.name}' by user '#{user.login}'"
    userfile.addlog "Owner set to '#{as_user.login}'" if as_user_id != self.user_id
    userfile.set_size
    [ true, userfile.id ]
  end

end

