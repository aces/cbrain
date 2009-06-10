
#
# CBRAIN Project
#
# $Id$
#

#
# This class provides an implementation for a data provider
# where the remote files are accessed through +ssh+ and +rsync+.
# The provider's files are stored in the 'cbrain enhanced
# directory tree'; such a tree stores the file "hello"
# of user "myuser" into a relative path like this:
#
#     /remote_dir/myuser/01/23/hello
#
# where the components "01" and "23" are computed based
# on the +hello+ string.
#
# For the list of API methods, see the DataProvider superclass.
#
class CbrainSshDataProvider < SshDataProvider

  def impl_sync_to_provider(userfile) #:nodoc:
    basename = userfile.name
    username = userfile.user.login
    twolevels = cache_subdirs(basename)
    userdir = Pathname.new(remote_dir) + username
    level1  = userdir                  + twolevels[0]
    level2  = level1                   + twolevels[1]
    bash_this("ssh -x -n #{option_port} #{ssh_user_host} \"bash -c 'mkdir #{userdir} #{level1} #{level2} >/dev/null 2>&1'\"")
    super(userfile)
  end

  def impl_provider_erase(userfile) #:nodoc:
    basename = userfile.name
    username = userfile.user.login
    twolevels = cache_subdirs(basename)
    userdir = Pathname.new(remote_dir) + username
    level1  = userdir                  + twolevels[0]
    level2  = level1                   + twolevels[1]
    full    = level2                   + basename
    bash_this("ssh -x -n #{option_port} #{ssh_user_host} \"bash -c '( rm -rf #{full};rmdir #{level2} #{level1} ) >/dev/null 2>&1'\"")
  end

  def impl_provider_list_all #:nodoc:
    raise "This data provider cannot be browsed."
  end

  # This method overrides the method in the immediate
  # superclass SshDataProvider.
  def remote_full_path(userfile) #:nodoc:
    basename = userfile.name
    username = userfile.user.login
    Pathname.new(remote_dir) + username + cache_subdir_path(basename) + basename
  end
  
end

