
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

  # Helper for scheduling a copy of files immediately.
  def self.setup!(user_id, userfile_ids, remote_resource_id=nil)
    ba         = self.local_new(user_id, userfile_ids, remote_resource_id)
    ba.save!
    ba
  end

  def process(item)
    userfile = Userfile.find(item)
    return process_single_file(userfile) if userfile.is_a?(SingleFile)
    return process_collection(userfile)  if userfile.is_a?(FileCollection)
  end

  def process_single_file(userfile)

    return [ false, "File is under transfer" ] if
      userfile.sync_status.to_a.any? { |ss| ss.status =~ /^To/ }

    return [ false, "File is not compressed" ] if
      userfile.name !~ /\.gz\z/i

    collision = userfile.class.where(
        :name             => userfile.name.sub(/\.gz\z/i,""),
        :data_provider_id => userfile.data_provider_id,
        :browse_path      => userfile.browse_path,
      )
    collision = collision.where(:user_id => userfile.user_id) if                                                                    ! userfile.data_provider.content_storage_shared_between_users?
    return [ false, "Another GZ file already exists" ] if
      collision.exists?

    userfile.gzip_content(:uncompress)
    return [ true, nil ]
  end

  def process_collection(userfile)
    return [ false, "FileCollection is under transfer" ] if
      userfile.sync_status.to_a.any? { |ss| ss.status =~ /^To/ }
    message = userfile.provider_unarchive
    ok      = message.blank?
    [ ok, message.presence ]
  end

  def prepare_dynamic_items
    populate_items_from_userfile_custom_filter
  end

end

