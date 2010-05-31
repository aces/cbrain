
#
# CBRAIN Project
#
# $Id$
#

#
# This class provides an implementation for a data provider
# where the remote files are accessed through +ssh+ and +rsync+.
# The provider's files are stored in the new 'CBRAIN enhanced
# directory tree'; such a tree stores the file "hello"
# into a relative path like this:
#
#     /remote_dir/01/23/45/hello
#
# where the components "01", "23" and "45" are computed based
# on the userfile's ID.
#
# For the list of API methods, see the DataProvider superclass.
#
class EnCbrainSshDataProvider < SshDataProvider

  Revision_info="$Id$"

  def is_browsable? #:nodoc:
    false
  end

  def impl_sync_to_provider(userfile) #:nodoc:
    threelevels = cache_subdirs_from_id(userfile.id)
    userdir = Pathname.new(remote_dir)
    level1  = userdir                  + threelevels[0]
    level2  = level1                   + threelevels[1]
    level3  = level2                   + threelevels[2]
    ssh_opts = self.ssh_shared_options
    bash_this("ssh -x -n #{ssh_opts} \"bash -c 'mkdir #{level1} #{level2} #{level3} >/dev/null 2>&1'\"")
    super(userfile)
  end

  def impl_provider_erase(userfile) #:nodoc:
    basename = userfile.name
    threelevels = cache_subdirs_from_id(userfile.id)
    userdir = Pathname.new(remote_dir)
    level1  = userdir                  + threelevels[0]
    level2  = level1                   + threelevels[1]
    level3  = level2                   + threelevels[2]
    ssh_opts = self.ssh_shared_options
    bash_this("ssh -x -n #{ssh_opts} \"bash -c '( rm -rf #{level3} ; rmdir #{level2} #{level1} ) >/dev/null 2>&1'\"")
    true
  end

  def impl_provider_rename(userfile,newname)  #:nodoc:
    oldpath   = provider_full_path(userfile)
    oldparent = oldpath.parent
    newpath   = oldparent + newname

    oldpath = oldpath.to_s
    newpath = newpath.to_s

    # We should create a nice state machine for the remote rename operations
    Net::SFTP.start(remote_host,remote_user, :port => remote_port, :auth_methods => 'publickey') do |sftp|

      req = sftp.lstat(newpath).wait
      return false if req.response.ok?   # file already exists ?

      req = sftp.rename(oldpath,newpath).wait
      return false unless req.response.ok?

      userfile.name = newname
      userfile.save
      return true

    end
  end

  def impl_provider_list_all(user=nil) #:nodoc:
    cb_error "This data provider cannot be browsed."
  end

  # This method overrides the method in the immediate
  # superclass SshDataProvider.
  def provider_full_path(userfile) #:nodoc:
    basename = userfile.name
    subdirs  = cache_subdirs_from_id(userfile.id)
    Pathname.new(remote_dir) + subdirs[0] + subdirs[1] + subdirs[2] + basename
  end

end

