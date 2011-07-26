
#
# CBRAIN Project
#
# $Id$
#

require 'socket'

# This module includes all  'wrapper' methods for Smart Data Providers.
module SmartDataProviderInterface

  Revision_info=CbrainFileRevision[__FILE__]

  # This method initialize an instance variable containing
  # the real data provider object we use to access the
  # data provider's files. The decision as to which class
  # it will belong to is based on the value of the
  # attribute +remote_host+ being the same as the current
  # system's hostname: if it is the case, we use the +localclass+,
  # otherwise we use the +networkclass+.
  def select_local_or_network_provider(localclass,networkclass)
    @local_provider   = localclass.new(   self.attributes.reject{ |k,v| k.to_sym == :type ||  k.to_sym == :id } )
    @network_provider = networkclass.new( self.attributes.reject{ |k,v| k.to_sym == :type ||  k.to_sym == :id } )
    if Socket.gethostname == remote_host && File.directory?(remote_dir)
      @provider = @local_provider
    else
      @provider = @network_provider
    end
    @provider.id = self.id # the real provider gets the id of the ActiveRecord object, even if it's never saved in the DB
    def @provider.save # for safety, intercept and prevent all saves
      cb_error "Internal error: attempt to save() real provider object for SmartDataProvider '#{self.name}'."
    end
    def @provider.save! # for safety, intercept and prevent all saves
      cb_error "Internal error: attempt to save!() real provider object for SmartDataProvider '#{self.name}'."
    end
    @provider
  end

  # This method returns the real data provider used
  # for implementing the behavior of all the methods
  # in the provider API. It is useful for debugging.
  # Attempts to save() the real provider will be prevented
  # by special intercept code when setting up the current
  # provider; this is for security reasons, as it's never
  # needed.
  def real_provider
    @provider
  end

  # This method is a utility method allowing access to
  # the remote path of userfiles as known by the network
  # class, even when the current smart provider is actually
  # configured to be local. This is not an official DataProvider
  # API method, but you can often find it implemented in
  # SSH-based Data Providers.
  def provider_full_path(userfile)
    if @network_provider.respond_to?(:provider_full_path) # this is not an official API method
      @network_provider.provider_full_path(userfile)
    else
      "(unknown remote path)"
    end
  end

  ###################################
  # ALL OFFICIAL API METHODS
  ###################################

  def is_alive? #:nodoc:
    @provider.is_alive?
  end

  def is_alive! #:nodoc:
    @provider.is_alive!
  end

  def is_browsable? #:nodoc:
    @provider.is_browsable?
  end

  def is_fast_syncing? #:nodoc:
    @provider.is_fast_syncing?
  end

  def allow_file_owner_change? #:nodoc:
    @provider.allow_file_owner_change?
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

end

