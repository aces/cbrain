
#
# CBRAIN Project
#
# $Id$
#

require 'socket'

# This class implements a 'wrapper' data provider that
# acts either as a VaultLocalDataProvider or a VaultSshDataProvider
# depending on whether or not the current hostname matches
# the value of the attribute remote_host.
#
# This means that in the case where the current Rails application
# runs on the same machine as the data provider, the faster
# and more efficient VaultLocalDataProvider will be used.
class VaultSmartDataProvider < DataProvider

  # This methods returns the real data provider used
  # for implementing the behavior of all the methods
  # in the provider API. It is useful for debugging.
  def real_provider
    @provider
  end

  def after_initialize #:nodoc:
    if Socket.gethostname == remote_host && File.directory?(remote_dir)
      @provider = VaultLocalDataProvider.new( self.attributes )
    else
      @provider = VaultSshDataProvider.new( self.attributes )
    end
  end

  def is_alive? #:nodoc:
    @provider.is_alive?
  end

  def is_alive! #:nodoc:
    @provider.is_alive!
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

  def cache_readhandle(userfile,&block) #:nodoc:
    @provider.cache_readhandle(userfile,&block)
  end

  def cache_writehandle(userfile,&block) #:nodoc:
    @provider.cache_writehandle(userfile,&block)
  end

  def cache_erase(userfile) #:nodoc:
    @provider.cache_erase(userfile)
  end

  def provider_erase(userfile) #:nodoc:
    @provider.provider_erase(userfile)
  end

  def provider_list_all #:nodoc:
    @provider.provider_list_all
  end

  # ActiveRecord callbacks

  # This creates the PROVIDER's cache directory
  def before_save #:nodoc:
    @provider.before_save
  end

  # This destroys the PROVIDER's cache directory
  def after_destroy #:nodoc:
    @provider.after_destroy
  end

end

