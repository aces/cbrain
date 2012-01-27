
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

#
# This this is an abstract class which represents data providers
# where the remote files are not even remote, they are local
# to the currently running rails application. 
#
# Subclasses are not meant to cache anything! The 'remote' files
# are in fact all local, and accessing the 'cached' files means
# accessing the real provider's files. All methods are adjusted
# so that their behavior is sensible.
#
# Not all API methods are defined here so this class is not meant
# to be instantiated directly.
#
# For the list of API methods, see the DataProvider superclass.
class LocalDataProvider < DataProvider

  Revision_info=CbrainFileRevision[__FILE__]

  # Returns true: local data providers are considered fast syncing.
  def is_fast_syncing?
    true
  end

  def provider_full_path(userfile) #:nodoc:
    self.cache_full_path(userfile)
  end

  def impl_is_alive? #:nodoc:
    return true if File.directory?(remote_dir)
    false
  end

  def impl_sync_to_cache(userfile) #:nodoc:
    true
  end

  def impl_sync_to_provider(userfile) #:nodoc:
    true
  end

  def impl_provider_list_all(user=nil) #:nodoc:
    cb_error "This data provider cannot be browsed."
  end
  
  # Redirects the call to cache_readhandle()
  def provider_readhandle(userfile, *args) #:nodoc:
    self.cache_readhandle(userfile, *args)
  end

  def impl_provider_collection_index(userfile, directory = :all, allowed_types = :regular) #:nodoc:
    self.cache_collection_index(userfile, directory, allowed_types)
  end

  protected

  # This method intercepts any attempts to use the protected
  # method used by the caching system. Typically, this would
  # be the result of a bad subclass implementation.
  def mkdir_cache_subdirs(userfile) #:nodoc:
    cb_error "No caching in this provider!"
  end

  # This method intercepts any attempts to use the protected
  # method used by the caching system. Typically, this would
  # be the result of a bad subclass implementation.
  def cache_subdirs_path(userfile) #:nodoc:
    cb_error "No caching in this provider!"
  end

  # This method intercepts any attempts to use the protected
  # method used by the caching system. Typically, this would
  # be the result of a bad subclass implementation.
  def cache_full_dirname(userfile) #:nodoc:
    cb_error "No caching in this provider!"
  end

  # This method intercepts any attempts to use the protected
  # method used by the caching system. Typically, this would
  # be the result of a bad subclass implementation.
  def cache_full_pathname(userfile) #:nodoc:
    cb_error "No caching in this provider!"
  end

end

