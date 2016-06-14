
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

require 'socket'

# This module includes all the 'wrapper' methods for Smart Data Providers.
module SmartDataProviderInterface

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # This method initialize an instance variable containing
  # the real data provider object we use to access the
  # data provider's files. The decision as to which class
  # it will belong to is based on the value of the
  # attribute +remote_host+ being the same as the current
  # system's hostname: if it is the case, we use the +localclass+,
  # otherwise we use the +networkclass+.
  def select_local_or_network_provider(localclass,networkclass)

    # Check for crucial attributes needed for proper initializaton
    dp_remote_dir = self.remote_dir  rescue nil
    dp_hostnames  = self.alternate_host.split(',').select { |host| host && ! host.blank? } rescue []
    dp_hostnames << self.remote_host rescue nil
    if dp_hostnames.empty? || dp_remote_dir.blank? # special case : usually when doing special select() on DPs with missing columns
      @provider = nil
      return @provider
    end

    # Create only one provider object, depending on whether we want a network provider
    # or a local provider
    if dp_hostnames.include?(Socket.gethostname) && File.directory?(dp_remote_dir)
      @provider = localclass.new
      @provider.make_all_accessible!
      @provider.attributes = self.attributes.reject{ |k,v| k.to_sym == :type ||  k.to_sym == :id  || ! localclass.columns_hash[k] }
    else
      @provider = networkclass.new
      @provider.make_all_accessible!
      @provider.attributes = self.attributes.reject{ |k,v| k.to_sym == :type ||  k.to_sym == :id  || ! networkclass.columns_hash[k] }
    end

    @provider.id = self.id

    @provider
  end

  # This method returns the real data provider used
  # for implementing the behavior of all the methods
  # in the provider API. It is useful for debugging.
  def real_provider
    @provider
  end

  ####################################
  # ALL OFFICIAL API METHODS ARE BELOW
  ####################################

  def is_alive? #:nodoc:
    @provider && @provider.is_alive?
  end

  def is_alive! #:nodoc:
    @provider && @provider.is_alive!
  end

  def is_browsable?(by_user = nil) #:nodoc:
    @provider && @provider.is_browsable?(by_user)
  end

  def is_fast_syncing? #:nodoc:
    @provider && @provider.is_fast_syncing?
  end

  def allow_file_owner_change? #:nodoc:
    @provider && @provider.allow_file_owner_change?
  end

  def sync_to_cache(userfile) #:nodoc:
    @provider.sync_to_cache(userfile)
  end

  def sync_to_provider(userfile) #:nodoc:
    @provider.sync_to_provider(userfile)
  end

  def cache_prepare(userfile) #:nodoc:
    @provider.cache_prepare(userfile)
  end

  def cache_full_path(userfile) #:nodoc:
    @provider.cache_full_path(userfile)
  end

  def provider_readhandle(userfile, *args, &block) #:nodoc:
    @provider.provider_readhandle(userfile, *args, &block)
  end

  def cache_readhandle(userfile, *args, &block) #:nodoc:
    @provider.cache_readhandle(userfile, *args, &block)
  end

  def cache_writehandle(userfile, *args, &block) #:nodoc:
    @provider.cache_writehandle(userfile, *args, &block)
  end

  def cache_copy_from_local_file(userfile,localfilename) #:nodoc:
    @provider.cache_copy_from_local_file(userfile,localfilename)
  end

  def cache_copy_to_local_file(userfile,localfilename) #:nodoc:
    @provider.cache_copy_to_local_file(userfile,localfilename)
  end

  def cache_erase(userfile) #:nodoc:
    @provider.cache_erase(userfile)
  end

  def cache_collection_index(userfile, directory = :all, allowed_types = :regular) #:nodoc:
    @provider.cache_collection_index(userfile, directory, allowed_types)
  end

  def provider_erase(userfile) #:nodoc:
    @provider.provider_erase(userfile)
  end

  def provider_rename(userfile, newname) #:nodoc:
    @provider.provider_rename(userfile, newname)
  end

  def provider_move_to_otherprovider(userfile, otherprovider, options = {}) #:nodoc:
    @provider.provider_move_to_otherprovider(userfile, otherprovider, options)
  end

  def provider_copy_to_otherprovider(userfile, otherprovider, options = {}) #:nodoc:
    @provider.provider_copy_to_otherprovider(userfile, otherprovider, options)
  end

  def provider_list_all(user=nil) #:nodoc:
    @provider.provider_list_all(user)
  end

  def provider_collection_index(userfile, directory = :all, allowed_types = :regular) #:nodoc:
    @provider.provider_collection_index(userfile, directory, allowed_types)
  end

  def provider_report(force_reload=nil) #:nodoc:
    @provider.provider_report(force_reload)
  end

  def provider_repair(issue) #:nodoc:
    @provider.provider_repair(issue)
  end

  # This method is specific to SSH data providers subclasses and not part of the official API
  def browse_remote_dir(user=nil) #:nodoc:
    @provider.browse_remote_dir(user)
  end

  # This method is a utility method allowing access to
  # the remote path of userfiles as known by the network
  # class, even when the current smart provider is actually
  # configured to be local.
  def provider_full_path(userfile) #:nodoc:
    if @provider.respond_to?(:provider_full_path)
      @provider.provider_full_path(userfile)
    else
      "(unknown remote path)"
    end
  end

end

