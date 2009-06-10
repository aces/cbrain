
#
# CBRAIN Project
#
# $Id$
#

require 'fileutils'

#
# This class provides an implementation for a data provider
# where the remote files are not even remote, they are local
# to the currently running rails application. The provider's
# files are stored in the 'cbrain enhanced
# directory tree'; such a tree stores the file "hello"
# of user "myuser" into a relative path like this:
#
#     /root_dir/myuser/01/23/hello
#
# where +root_dir+ is the data provider's +remote_dir+ (a local
# directory) and the components "01" and "23" are computed based
# on the +hello+ string.
#
# This data provider does not cache anything! The 'remote' files
# are in fact all local, and accesing the 'cached' files mean
# accessing the real provider's files. All methods are adjusted
# so that their behavior is sensible.
#
# For the list of API methods, see the DataProvider superclass.
#
class CbrainLocalDataProvider < DataProvider

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
    twolevels = cache_subdirs(basename)
    userdir = Pathname.new(remote_dir) + username
    level1  = userdir                  + twolevels[0]
    level2  = level1                   + twolevels[1]
    Dir.mkdir(userdir) unless File.directory?(userdir)
    Dir.mkdir(level1)  unless File.directory?(level1)
    Dir.mkdir(level2)  unless File.directory?(level2)
    true
  end

  def cache_full_path(userfile) #:nodoc:
    basename  = userfile.name
    username  = userfile.user.login
    twolevels = cache_subdirs(basename)
    Pathname.new(remote_dir) + username + twolevels[0] + twolevels[1] + basename
  end

  def cache_erase(userfile) #:nodoc:
    true
  end

  def impl_provider_erase(userfile)  #:nodoc:
    basename = userfile.name
    username  = userfile.user.login
    twolevels = cache_subdirs(basename)
    FileUtils.remove_entry(cache_full_path(basename), true)
    begin
      Dir.rmdir(Pathname.new(remote_dir) + username + twolevels[0] + twolevels[1])
      Dir.rmdir(Pathname.new(remote_dir) + username + twolevels[0])
    rescue
    end
  end

  def impl_provider_list_all #:nodoc:
    raise "This data provider cannot be browsed."
  end

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

