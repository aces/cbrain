
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

# Verify that a Data Provider is reachable
class BackgroundActivity::VerifyDataProvider < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Helper for scheduling a check immediately.
  def self.setup!(user_id, data_provider_ids, remote_resource_id=nil)
    ba         = self.local_new(user_id, data_provider_ids, remote_resource_id)
    ba.save!
    ba
  end

  def process(item)
    data_provider = DataProvider.find(item)
    if data_provider.is_a?(UserkeyFlatDirSshDataProvider)
      dp_user = data_provider.user
      key_ok  = dp_user.ssh_key rescue nil
      return [ false, "Missing SSH key for #{dp_user.login}" ] unless key_ok
    end
    is_alive = data_provider.is_alive_with_caching?
    return [ true,  "" ] if is_alive
    return [ false, "Not alive: #{data_provider.name}" ]
  end

end

