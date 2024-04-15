
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

# Clean cached userfiles
class BackgroundActivity::CleanCache < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_dynamic_bac_presence_of_option :days_older

  def pretty_name
    "Clean cache"
  end

  def process(item)
    userfile = Userfile.find(item)
    return [ false, "File is under transfer" ] if
      userfile.local_sync_status&.status.to_s =~ /^To/
    userfile.cache_erase
    [ true, userfile.id ]
  end

  def prepare_dynamic_items
    days_older       = self.options[:days_older] || 30
    with_user_ids    = self.options[:with_user_ids]
    without_user_ids = self.options[:without_user_ids]
    with_types       = self.options[:with_types]
    without_types    = self.options[:without_types]

    # Base scopes: files cached locally and having been access longer that days_older
    scope = Userfile.all.joins(:sync_status)
      .where('sync_status.remote_resource_id' => self.remote_resource_id)
      .where('sync_status.accessed_at < ?', days_older.to_i.days.ago)

    # Add optional filters
    scope = scope.where(    'userfiles.user_id' => with_user_ids)    if with_user_ids.present?
    scope = scope.where.not('userfiles.user_id' => without_user_ids) if without_user_ids.present?
    scope = scope.where(    'userfiles.type'    => with_types)       if with_types.present?
    scope = scope.where.not('userfiles.type'    => without_types)    if without_types.present?

    # The IDs of these files are what we need to work on
    self.items = scope.pluck('userfiles.id')
  end

end

