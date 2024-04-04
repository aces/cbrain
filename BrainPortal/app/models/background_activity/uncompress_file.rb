
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

# Uncompress files or file collections.
class BackgroundActivity::UncompressFile < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_dynamic_bac_presence_of_option :userfile_custom_filter_id

  def pretty_name
    "Uncompress files"
  end

  # Helper for scheduling a copy of files immediately.
  def self.setup!(user_id, userfile_ids, remote_resource_id=nil)
    ba         = self.local_new(user_id, userfile_ids, remote_resource_id)
    ba.save!
    ba
  end

  def process(item)
    userfile = Userfile.find(item)
    return process_single_file(userfile) if userfile_is_a?(SingleFile)
    return process_collection(userfile)  if userfile_is_a?(FileCollection)
  end

  def process_single_file(userfile)
    name = userfile.name
    return [ false, "File #{name} is under transfer" ] if
      userfile.sync_status.to_a.any? { |ss| ss.status =~ /^To/ }
    return [ false, "File #{name} is not compressed" ] if
      userfile.name !~ /\.gz\z/i
    userfile.gzip_content(:uncompress)
    [ true, "Uncompressed: #{name}" ]
  end

  def process_collection(userfile)
    name = userfile.name
    return [ false, "FileCollection #{name} is under transfer" ] if
      userfile.sync_status.to_a.any? { |ss| ss.status =~ /^To/ }
    message = userfile.provider_unarchive
    ok      = message.blank?
    message = ok ? "Unarchived: #{name}" : message
    [ ok, message ]
  end

  def prepare_dynamic_items
    populate_items_from_userfile_custom_filter
  end

end

