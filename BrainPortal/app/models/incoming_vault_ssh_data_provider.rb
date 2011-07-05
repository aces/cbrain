
#
# CBRAIN Project
#
# $Id$
#

#
# This class is exactly like VaultSshDataProvider, but
# it also has the ability to browse a subdirectory named
# after a user when calling provider_list_all(user).
#
class IncomingVaultSshDataProvider < VaultSshDataProvider

  Revision_info=CbrainFileRevision[__FILE__]

  def is_browsable? #:nodoc:
    true
  end

  # We browse ONLY the user's specific subdir.
  def browse_remote_dir(user=nil) #:nodoc:
    if user
      self.remote_dir + "/#{user.login}"
    else
      self.remote_dir
    end
  end

end

