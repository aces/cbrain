
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

  Revision_info="$Id$"

  def is_browsable? #:nodoc:
    false
  end

  def impl_sync_to_provider(userfile) #:nodoc:
    basename = userfile.name
    username = userfile.user.login
    twolevels = cache_subdirs(basename)
    userdir = Pathname.new(remote_dir) + username
    level1  = userdir                  + twolevels[0]
    level2  = level1                   + twolevels[1]
    ssh_opts = self.ssh_shared_options
    bash_this("ssh -x -n #{ssh_opts} \"bash -c 'mkdir #{userdir} #{level1} #{level2} >/dev/null 2>&1'\"")
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
    ssh_opts = self.ssh_shared_options
    bash_this("ssh -x -n #{ssh_opts} \"bash -c '( rm -rf #{full};rmdir #{level2} #{level1} ) >/dev/null 2>&1'\"")
    true
  end

  def impl_provider_rename(userfile,newname)  #:nodoc:
    oldname   = userfile.name
    username  = userfile.user.login

    old2levs  = cache_subdirs(oldname)
    oldpath   = Pathname.new(remote_dir) + username + old2levs[0] + old2levs[1] + oldname

    new2levs  = cache_subdirs(newname)
    newlev1   = Pathname.new(remote_dir) + username + new2levs[0]
    newlev2   = newlev1 + new2levs[1]
    newpath   = newlev2 + newname

    newlev1 = newlev1.to_s
    newlev2 = newlev2.to_s
    oldpath = oldpath.to_s
    newpath = newpath.to_s

    # We should create a nice state machine for the remote rename operations
    Net::SFTP.start(remote_host,remote_user, :port => remote_port, :auth_methods => 'publickey') do |sftp|

      begin
        sftp.mkdir!(newlev1)
      rescue ; end
      begin
        sftp.mkdir!(newlev2)
      rescue ; end

      req = sftp.lstat(newpath).wait
      return false if req.response.ok?   # file already exists ?

      req = sftp.rename(oldpath,newpath).wait
      return false unless req.response.ok?

      userfile.name = newname
      return true

    end
  end

  def impl_provider_list_all #:nodoc:
    cb_error "This data provider cannot be browsed."
  end

  # This method overrides the method in the immediate
  # superclass SshDataProvider.
  def remote_full_path(userfile) #:nodoc:
    basename = userfile.name
    username = userfile.user.login
    Pathname.new(remote_dir) + username + cache_subdir_path(basename) + basename
  end
  
end

