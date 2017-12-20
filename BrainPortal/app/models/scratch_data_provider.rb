
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
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

# This data provider class is special in that it doesn't
# store the Userfile data anywhere but in the local cache
# of the CBRAIN Rails app. So all content is meant to be
# just temporary (even if the entry in the userfiles
# tables stays around) and the content itself might differ
# from one rails app to the others. All other operations are
# conceptually similar to a standard data provider, except:
#
# * The sync_to_cache() operation always succeed immediately
#   if the file is InSync, and raises an exception otherwise
#
# * The sync_to_provider() operation always succeed immediately,
#   therefore registering that whatever is in the local cache
#   is the content of the file (that includes having no content!)
#
# There is only need for ONE such data provider in the entire
# CBRAIN system and it is usually created by the sanity check
# at boot time. The same DP will be used by all Rails app
# to store locally the content of the scratch files.
#
# Programmers are encouraged to keep the scratch userfiles hidden to
# normal users by creating them with a user_id set to the admin user's ID,
# and the group_id set to the admin user's ID.
#
# See also the Userfile helper method find_or_create_as_scratch().
class ScratchDataProvider < LocalDataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Utility: returns the single instance of this object
  # that the system needs. Cached.
  def self.main
    @_main_ ||= self.first
  end

  # Returns true if the local Rails app has a properly configured
  # cache directory.
  def impl_is_alive? #:nodoc:
    self.this_is_a_proper_cache_dir!(self.class.cache_rootdir.to_s)
    true
  rescue
    false
  end

  # Returns true if content for userfile has been previous stored in the cache.
  # raises an exception otherwise.
  def impl_sync_to_cache(userfile)
    return true if userfile.local_sync_status.try(:status) == 'InSync'
    cb_error "No scratch content available for userfile #{userfile.id} on resource #{RemoteResource.current_resource.name}"
  end

  # This just marks whatever data is currently in the cache
  # as being the true content of the userfile, as seen locally.
  def impl_sync_to_provider(userfile)
    true # will just mark it as 'InSync'
  end

  # Not supported; cache management and integrity is already handled by the caching subsystem
  def impl_provider_report #:nodoc:
    return []
  end

  #==============================================================
  # Caching Subsytem Behavior Restoration
  #==============================================================
  # Because we inherit from LocalDataProvider which overrides
  # cache_full_path to return the provider side path, we need
  # to return to the correct caching subsystem methods just like
  # the base class DataProvider did. The following three methods
  # re-implement them.

  # Restores DataProvider code, which was overrided in LocalDataProvider.
  # See the code in DataProvider for more explanations.
  def cache_full_path(userfile) #:nodoc:
    cache_full_pathname(userfile) # this is the internal private version with a REAL path to the REAL cache
  end

  # Restores DataProvider code, which was overrided in LocalDataProvider.
  # See the code in DataProvider for more explanations.
  def cache_prepare(userfile) #:nodoc:
    SyncStatus.ready_to_modify_cache(userfile) do
      mkdir_cache_subdirs(userfile)
    end
    true
  end

  # Restores DataProvider code, which was overrided in LocalDataProvider.
  # See the code in DataProvider for more explanations.
  def cache_erase(userfile) #:nodoc:
    SyncStatus.ready_to_modify_cache(userfile,:destroy) do
      begin
        fullpath = cache_full_pathname(userfile)
        level2 = fullpath.parent
        FileUtils.remove_entry(level2,true) rescue true
        level1 = level2.parent
        Dir.rmdir(level1)
        level0 = level1.parent
        Dir.rmdir(level0)
      rescue Errno::ENOENT, Errno::ENOTEMPTY
      end
    end
    true
  end

end

