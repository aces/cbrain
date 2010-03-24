
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
class CbrainLocalDataProvider < LocalDataProvider

  Revision_info="$Id$"

  def cache_prepare(userfile) #:nodoc:
    SyncStatus.ready_to_modify_cache(userfile) do
      basename  = userfile.name
      username  = userfile.user.login
      twolevels = cache_subdirs_from_name(basename)
      userdir = Pathname.new(remote_dir) + username
      level1  = userdir                  + twolevels[0]
      level2  = level1                   + twolevels[1]
      Dir.mkdir(userdir) unless File.directory?(userdir)
      Dir.mkdir(level1)  unless File.directory?(level1)
      Dir.mkdir(level2)  unless File.directory?(level2)
      true
    end
  end

  def cache_full_path(userfile) #:nodoc:
    basename  = userfile.name
    username  = userfile.user.login
    twolevels = cache_subdirs_from_name(basename)
    Pathname.new(remote_dir) + username + twolevels[0] + twolevels[1] + basename
  end

  def cache_erase(userfile) #:nodoc:
    SyncStatus.ready_to_modify_cache(userfile,'ProvNewer') do
      true
    end
  end

  def impl_provider_erase(userfile)  #:nodoc:
    basename  = userfile.name
    username  = userfile.user.login
    twolevels = cache_subdirs_from_name(basename)
    FileUtils.remove_entry(cache_full_path(userfile).to_s, true)
    begin
      Dir.rmdir(Pathname.new(remote_dir) + username + twolevels[0] + twolevels[1])
      Dir.rmdir(Pathname.new(remote_dir) + username + twolevels[0])
    rescue Errno::ENOENT, Errno::ENOTEMPTY => ex
      # It's OK if any of the rmdir fails, and we simply ignore that.
    end
    true
  end

  def impl_provider_rename(userfile,newname)  #:nodoc:
    oldname   = userfile.name
    username  = userfile.user.login
    oldpath   = userfile.cache_full_path
    old2levs  = cache_subdirs_from_name(oldname)
    new2levs  = cache_subdirs_from_name(newname)
    newlev1 = Pathname.new(remote_dir) + username + new2levs[0]
    newlev2 = newlev1 + new2levs[1]
    newpath = newlev2 + newname.to_s

    newlev1 = newlev1.to_s
    newlev2 = newlev2.to_s
    oldpath = oldpath.to_s
    newpath = newpath.to_s

    begin
      Dir.mkdir(newlev1) unless File.directory?(newlev1)
      Dir.mkdir(newlev2) unless File.directory?(newlev2)
      FileUtils.remove_entry(newpath, true)
    rescue
    end
    return false unless FileUtils.move(oldpath,newpath)
    #impl_provider_erase(userfile) # just to erase old subdirs paths
    userfile.name = newname
    true
  end

end

