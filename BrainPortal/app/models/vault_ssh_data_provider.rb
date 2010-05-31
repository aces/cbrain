
#
# CBRAIN Project
#
# $Id$
#

#
# This class provides an implementation for a data provider
# where the remote files are accessed through +ssh+ and +rsync+.
# The provider's files are stored in a flat directory, two levels
# deep, directly specified by the object's +remote_dir+
# attribute and the user's login name. The file "hello"
# of user "myuser" is thus stored into a path like this:
#
#     /remote_dir/myuser/hello
#
# For the list of API methods, see the DataProvider superclass.
#
class VaultSshDataProvider < SshDataProvider

  Revision_info="$Id$"

  def is_browsable? #:nodoc:
    false
  end

  def impl_sync_to_provider(userfile) #:nodoc:
    username = userfile.user.login
    userdir = Pathname.new(remote_dir) + username
    ssh_opts = self.ssh_shared_options
    bash_this("ssh -x -n #{ssh_opts} \"bash -c 'mkdir #{userdir} >/dev/null 2>&1'\"")
    super(userfile)
  end

  def impl_provider_list_all(user=nil) #:nodoc:
    cb_error "This data provider cannot be browsed." unless self.is_browsable?
    super(user)
  end

  # This method overrides the method in the immediate
  # superclass SshDataProvider
  def provider_full_path(userfile) #:nodoc:
    basename = userfile.name
    username = userfile.user.login
    Pathname.new(remote_dir) + username + basename
  end
  
end

