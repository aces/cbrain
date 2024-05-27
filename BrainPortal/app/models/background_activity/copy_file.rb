
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

# Copy a file
class BackgroundActivity::CopyFile < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_bac_presence_of_option         :dest_data_provider_id
  validates_dynamic_bac_presence_of_option :userfile_custom_filter_id

  # Helper for scheduling a copy of files immediately.
  def self.setup!(user_id, userfile_ids, remote_resource_id, dest_data_provider_id, options={})
    ba         = self.local_new(user_id, userfile_ids, remote_resource_id)
    ba.options = options.merge( :dest_data_provider_id => dest_data_provider_id )
    ba.save!
    ba
  end

  def process(item)
    userfile     = Userfile.find(item)
    dest_dp_id   = self.options[:dest_data_provider_id]
    dest_dp      = DataProvider.find(dest_dp_id)

    # This option is rarely used. The CBRAIN main interface
    # doesn't provide any means of setting this. It is used
    # by special external API calls that require copying of only a
    # subset of a FileCollection. Also, only some specific
    # types of destination DPs support the option.
    userfile.sync_select_patterns = self.options[:sync_select_patterns] # can be nil

    # Main operation and return status
    new_userfile = userfile.provider_copy_to_otherprovider(dest_dp, self.options || {})

    DataUsage.increase_copies(self.user, userfile) if new_userfile.is_a?(Userfile)

    return [ true, new_userfile.id ] if new_userfile.is_a?(Userfile)
    return [ true, "Skipped"      ]  if new_userfile == true
    return [ false, "Failed to copy '#{userfile.name}'" ]
  end

  def prepare_dynamic_items
    populate_items_from_userfile_custom_filter
  end

end

