
#
# CBRAIN Project
#
# Copyright (C) 2008-2022
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

# This module adds automatic cleanup of cached file inputs
# after a task completes successfully.
#
# To include the module automatically at boot time
# in a task integrated by Boutiques, add a new entry
# in the 'custom' section of the descriptor, like this:
#
#   "custom": {
#       "cbrain:integrator_modules": {
#           "BoutiquesInputCacheCleaner": [
#             "my_input1",
#             "my_input2"
#           ]
#       }
#   }
#
# In the example above, the cached content of any userfile(s) selected for the
# file inputs named 'my_input1' or 'my_input2' will be deleted after the task
# completes properly.
#
# For data safety, the cleanup only happens when two conditions are met:
# 1) the files were not already in the cache before the task was set up
# 2) after the task completes, the files' synchronization timestamps
# indicate that they have not been used by other processes too.
module BoutiquesInputCacheCleaner

  # Note: to access the revision info of the module,
  # you need to access the constant directly, the
  # object method revision_info() won't work.
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def setup #:nodoc:

    # BEFORE standard setup: identify userfiles that are not synced at all
    # at this point.
    userfile_ids = to_clean_userfile_ids()
    self.meta[:input_userfile_ids_not_synced] = userfile_ids.select do |userfile_id|
      sync_status = Userfile.find(userfile_id).local_sync_status
      sync_status.blank? || sync_status.status == 'ProvNewer'
    end

    # Standard setup
    result = super

    # AFTER standard setup: record a timestamp
    self.meta[:setup_time] = Time.now

    result
  end

  def save_results #:nodoc:

    return false unless super # call all the normal code

    # Fetch the two pieces of info we prepared in setup() above
    setup_time     = self.meta[:setup_time]
    not_synced_ids = self.meta[:input_userfile_ids_not_synced]
    return true if setup_time.blank?
    return true if not_synced_ids.blank?

    # For each userfile that were not synced before
    # we set up the task, see if they have been synced by others
    # since then. If not, we can delete the cache.
    not_synced_ids.each do |userfile_id|

      userfile = Userfile.find(userfile_id)
      last_cache_access_time = userfile.local_sync_status&.accessed_at

      next unless last_cache_access_time  # skip, already unsynced
      next if     last_cache_access_time >= setup_time  # skip, file is being accessed by another task

      userfile.cache_erase
      self.addlog("BoutiquesInputCacheCleaner deleted cache of '#{userfile.name}'")

    end

    # Some internal cleanup
    self.meta[:setup_time]                    = nil
    self.meta[:input_userfile_ids_not_synced] = nil

    true
  end

  # Returns the list of userfile IDs associated
  # with the boutiques inputs specified with this
  # module's config.
  def to_clean_userfile_ids #:nodoc:
    descriptor = self.descriptor_for_save_results
    input_ids  = descriptor.custom_module_info('BoutiquesInputCacheCleaner')
    input_ids # 'my_input1', 'my_input2'
      .map { |inputid| invoke_params[inputid] } # the userfile ID(s) in the params; scalar or array
      .flatten                                  # flatten them all
      .map(&:presence)
      .compact # returns a clean list of Userfile IDs
  end

end
