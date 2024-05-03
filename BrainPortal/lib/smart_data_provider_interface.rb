
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
    dp_hostnames  = (self.alternate_host.presence || "").split(/[\s,]+/).map(&:presence).compact
    dp_hostnames << self.remote_host rescue nil
    if dp_hostnames.empty? || dp_remote_dir.blank? # special case : usually when doing special select() on DPs with missing columns
      @real_provider = nil
      return @real_provider
    end
    dp_hostnames = dp_hostnames.map { |x| x.downcase }

    # Create only one provider object, depending on whether we want a network provider
    # or a local provider
    if dp_hostnames.include?(Socket.gethostname.downcase) && File.directory?(dp_remote_dir)
      @real_provider = localclass.new
    else
      @real_provider = networkclass.new
    end

    # Copy attributes to the internal real provider object
    @real_provider.attributes = self.attributes.reject { |k,v| k.to_sym == :type ||  k.to_sym == :id  || ! @real_provider.class.columns_hash[k] }
    @real_provider.id = self.id # the real provider gets the id of the ActiveRecord object, even if it's never saved in the DB
    @real_provider.readonly!

    # These methods are used to intercept and prevent calls to 'save' on the two internal providers objects
    @real_provider.class_eval do
      [ :save, :save!, :update_attribute, :update_attributes, :update_attributes! ].each do |bad_method|
        define_method(bad_method) do |*args|
          cb_error "Internal error: attempt to invoke method '#{bad_method}' on internal #{@real_provider.class == localclass ? "local" : "network"} provider object for SmartDataProvider '#{@real_provider.name}'"
        end
      end
    end

    @real_provider
  end

  # This method returns the real data provider used
  # for implementing the behavior of all the methods
  # in the provider API. It is useful for debugging.
  # Attempts to save() the real provider will be prevented
  # by special intercept code when setting up the current
  # provider; this is for security reasons, as saving
  # the real provider object should never be needed
  # in any way.
  def real_provider
    @real_provider
  end

  ####################################
  # ALL OFFICIAL API METHODS ARE BELOW
  ####################################

  def is_alive? #:nodoc:
    @real_provider.is_alive?
  end

  def is_alive! #:nodoc:
    @real_provider.is_alive!
  end

  def is_browsable?(by_user = nil) #:nodoc:
    @real_provider.is_browsable?(by_user)
  end

  def is_fast_syncing? #:nodoc:
    @real_provider.is_fast_syncing?
  end

  def allow_file_owner_change? #:nodoc:
    @real_provider.allow_file_owner_change?
  end

  def content_storage_shared_between_users? #:nodoc:
    @real_provider.content_storage_shared_between_users?
  end

  def has_browse_path_capabilities?
    @real_provider.has_browse_path_capabilities?
  end

  def can_upload_directly_from_path?
    @real_provider.can_upload_directly_from_path?
  end

  def sync_to_cache(userfile) #:nodoc:
    @real_provider.sync_to_cache(userfile)
  end

  def sync_to_provider(userfile) #:nodoc:
    @real_provider.sync_to_provider(userfile)
  end

  def cache_prepare(userfile) #:nodoc:
    @real_provider.cache_prepare(userfile)
  end

  def cache_full_path(userfile) #:nodoc:
    @real_provider.cache_full_path(userfile)
  end

  def provider_readhandle(userfile, *args, &block) #:nodoc:
    @real_provider.provider_readhandle(userfile, *args, &block)
  end

  def cache_readhandle(userfile, *args, &block) #:nodoc:
    @real_provider.cache_readhandle(userfile, *args, &block)
  end

  def cache_writehandle(userfile, *args, &block) #:nodoc:
    @real_provider.cache_writehandle(userfile, *args, &block)
  end

  def cache_copy_from_local_file(userfile,localfilename) #:nodoc:
    @real_provider.cache_copy_from_local_file(userfile,localfilename)
  end

  def cache_copy_to_local_file(userfile,localfilename) #:nodoc:
    @real_provider.cache_copy_to_local_file(userfile,localfilename)
  end

  def cache_erase(userfile) #:nodoc:
    @real_provider.cache_erase(userfile)
  end

  def cache_collection_index(userfile, directory = :all, allowed_types = :regular) #:nodoc:
    @real_provider.cache_collection_index(userfile, directory, allowed_types)
  end

  def provider_erase(userfile) #:nodoc:
    @real_provider.provider_erase(userfile)
  end

  def provider_rename(userfile, newname) #:nodoc:
    @real_provider.provider_rename(userfile, newname)
  end

  def provider_move_to_otherprovider(userfile, otherprovider, options = {}) #:nodoc:
    @real_provider.provider_move_to_otherprovider(userfile, otherprovider, options)
  end

  def provider_copy_to_otherprovider(userfile, otherprovider, options = {}) #:nodoc:
    @real_provider.provider_copy_to_otherprovider(userfile, otherprovider, options)
  end

  def provider_list_all(user=nil,browse_path=nil) #:nodoc:
    @real_provider.provider_list_all(user,browse_path)
  end

  def provider_collection_index(userfile, directory = :all, allowed_types = :regular) #:nodoc:
    @real_provider.provider_collection_index(userfile, directory, allowed_types)
  end

  def provider_report(force_reload=nil) #:nodoc:
    @real_provider.provider_report(force_reload)
  end

  def provider_repair(issue) #:nodoc:
    @real_provider.provider_repair(issue)
  end

  def provider_upload_from_local_file(userfile, localpath)
    @real_provider.provider_upload_from_local_file(userfile, localpath)
  end

  # This method is specific to SSH data providers subclasses and not part of the official API
  def browse_remote_dir(user=nil) #:nodoc:
    @real_provider.browse_remote_dir(user)
  end

  # This method is a utility method allowing access to
  # the remote path of userfiles as known by the network
  # class, even when the current smart provider is actually
  # configured to be local.
  def provider_full_path(userfile) #:nodoc:
    if @real_provider.respond_to?(:provider_full_path)
      @real_provider.provider_full_path(userfile)
    else
      "(unknown remote path)"
    end
  end

end

