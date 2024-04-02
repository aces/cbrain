
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
class BackgroundActivity::ArchiveCollection < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def pretty_name
    num=self.items.size
    "Archive #{num} file#{num > 1 ? 's' : ''}"
  end

  # Helper for scheduling a copy of files immediately.
  def self.setup!(user_id, userfile_ids, remote_resource_id)
    ba         = self.local_new(user_id, userfile_ids, remote_resource_id)
    ba.save!
    ba
  end

  def process(item)
    userfile = FileCollection.where(:archived => false).find(item)
    return [ false, "FileCollection #{item} is under transfer" ] if
      userfile.sync_status.to_a.any? { |ss| ss.status =~ /^To/ }
    message = userfile.provider_archive
    ok      = message.blank?
    message = ok ? "Archived: #{item}" : message
    [ ok, message ]
  end

  def prepare_scheduled_items
    userfile_custom_filter = UserfileCustomFilter.find(self.options[:userfile_custom_filter_id])
    self.items = userfile_custom_filter.filter_scope(FileCollection.all).pluck(:id)
  end

end

