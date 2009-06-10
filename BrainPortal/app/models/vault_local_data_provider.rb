
#
# CBRAIN Project
#
# $Id$
#

#
# This class provides an implementation for a data provider
# where the remote files are not even remote, they are local
# to the currently running rails application. The provider's
# files are stored in a flat directory, two levels
# deep, directly specified by the object's +remote_dir+
# attribute and the user's login name. The file "hello"
# of user "myuser" is thus stored into a path like this:
#
#     /root_dir/myuser/hello
#
# where +root_dir+ is the data provider's +remote_dir+ (a local
# directory).
#
# This data provider does not cache anything! The 'remote' files
# are in fact all local, and accessing the 'cached' files mean
# accessing the real provider's files. All methods are adjusted
# so that their behavior is sensible.
#
# For the list of API methods, see the DataProvider superclass.
#
class VaultLocalDataProvider < DataProvider

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

  def cache_prepare(userfile) #:nodoc:
    basename  = userfile.name
    username  = userfile.user.login
    userdir = Pathname.new(remote_dir) + username
    Dir.mkdir(userdir) unless File.directory?(userdir)
    true
  end

  def cache_full_path(userfile) #:nodoc:
    basename  = userfile.name
    username  = userfile.user.login
    Pathname.new(remote_dir) + username + basename
  end

  def cache_erase(userfile) #:nodoc:
    true
  end

  def impl_provider_erase(userfile) #:nodoc:
    FileUtils.remove_entry(cache_full_path(userfile), true)
  end

  def impl_provider_list_all #:nodoc:
    raise "This data provider cannot be browsed."
  end

  # Callbacks overrides

  def before_save #:nodoc:
    true
  end

  def after_destroy #:nodoc:
    true
  end

  protected

  # Root directory for DataProvider's cache dir:
  #    "/CbrainCacheDir/ProviderName"
  def cache_providerdir #:nodoc:
    raise "No caching in this provider!"
  end

  # Make, if needed, the two subdirectory levels for a cached file:
  # mkdir "/CbrainCacheDir/ProviderName/34"
  # mkdir "/CbrainCacheDir/ProviderName/34/45"
  def mkdir_cache_subdirs(basename) #:nodoc:
    raise "No caching in this provider!"
  end

  # Returns the relative path of the two subdirectory levels:
  # "34/45"
  def cache_subdir_path(basename) #:nodoc:
    raise "No caching in this provider!"
  end

  # Returns the full path of the two subdirectory levels:
  # "/CbrainCacheDir/ProviderName/34/45"
  def cache_full_dirname(basename) #:nodoc:
    raise "No caching in this provider!"
  end

  # Returns the full path of the cached file:
  # "/CbrainCacheDir/ProviderName/34/45/basename"
  def cache_full_pathname(basename) #:nodoc:
    raise "No caching in this provider!"
  end

end

