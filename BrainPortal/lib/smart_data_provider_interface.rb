
#
# CBRAIN Project
#
# $Id$
#

require 'socket'

# This module includes all  'wrapper' methods for Smart Data Providers.
module SmartDataProviderInterface

  Revision_info="$Id$"

  # This method initialize an instance variable containing
  # the true data provider object we use to access the
  # data provider's files. The decision as to which class
  # it will belong to is based on the value of the
  # attribute +remote_host+ being the same as the current
  # system's hostname: if it is the case, we use a local
  # class, otherwise we use a network class.
  def select_local_or_network_provider(localclass,networkclass)
    @local_provider   = localclass.new(   self.attributes.reject{ |k,v| k.to_sym == :type ||  k.to_sym == :id } )
    @network_provider = networkclass.new( self.attributes.reject{ |k,v| k.to_sym == :type ||  k.to_sym == :id } )
    if Socket.gethostname == remote_host && File.directory?(remote_dir)
      @provider = @local_provider
    else
      @provider = @network_provider
    end
  end

  # This method returns the real data provider used
  # for implementing the behavior of all the methods
  # in the provider API. It is useful for debugging.
  def real_provider
    @provider
  end

  # This method is a utility method allowing access to
  # the remote path of userfiles as know by the network
  # class, even when the current smart provider is actually
  # configured to be local. This is not an official DP
  # API method.
  def remote_full_path(userfile)
    if @network_provider.respond_to?(:remote_full_path) # this is not an official API method
      @network_provider.remote_full_path(userfile)
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

  def cache_writehandle(userfile,&block) #:nodoc:
    @provider.cache_writehandle(userfile,&block)
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

  def cache_collection_index(userfile, *args) #:nodoc:
    @provider.cache_collection_index(userfile, *args)
  end

  def provider_erase(userfile) #:nodoc:
    @provider.provider_erase(userfile)
  end

  def provider_rename(userfile,newname) #:nodoc:
    @provider.provider_rename(userfile,newname)
  end

  def provider_move_to_otherprovider(userfile,otherprovider) #:nodoc:
    @provider.provider_move_to_otherprovider(userfile,otherprovider)
  end

  def provider_copy_to_otherprovider(userfile,otherprovider,newname = nil) #:nodoc:
    @provider.provider_copy_to_otherprovider(userfile,otherprovider,newname)
  end

  def provider_list_all #:nodoc:
    @provider.provider_list_all
  end

  def provider_collection_index(userfile, *args) #:nodoc:
    @provider.provider_collection_index(userfile, *args)
  end

end

