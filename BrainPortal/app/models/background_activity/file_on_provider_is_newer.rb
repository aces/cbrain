
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

# Flag that files are potentionally newer on
# the DataProvider than whatever is currently in the
# cache. The cached data is not affected.
class BackgroundActivity::FileOnProviderIsNewer < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_dynamic_bac_presence_of_option :userfile_custom_filter_id

  # Helper for scheduling a batch mark-as-newer operation immediately
  def self.setup!(user_id, userfile_ids, remote_resource_id=nil)
    ba         = self.local_new(user_id, userfile_ids, remote_resource_id)
    ba.save!
    ba
  end

  def process(item)
    Userfile.find(item).provider_is_newer
    [ true,  "Ok" ]
  end

  def prepare_dynamic_items
    populate_items_from_userfile_custom_filter
  end

end

