
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

# Unregister files on a browsable DP
class BackgroundActivity::UnregisterFile < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_dynamic_bac_presence_of_option :userfile_custom_filter_id

  def pretty_name
    "Unregister files"
  end

  # Helper for scheduling a copy of files immediately.
  def self.setup!(user_id, userfile_ids, remote_resource_id=nil)
    ba         = self.local_new(user_id, userfile_ids, remote_resource_id)
    ba.save!
    ba
  end

  def process(item)
    userfile = Userfile.find(item)
    return [ false, "File is under transfer" ] if
      userfile.sync_status.to_a.any? { |ss| ss.status =~ /^To/ }
    return [ false, "File is not on a browsable DataProvider" ] if
      ! userfile.data_provider.is_browsable?
    userfile.keep_dp_content_on_destroy = true
    ok = userfile.destroy # only remove entries from DB, does not affect file content
    [ ok, "Unregistered" ]
  end

  # Currently, there is no user interface to schedule
  # this sort of operation.
  def prepare_dynamic_items
    populate_items_from_userfile_custom_filter
  end

end

