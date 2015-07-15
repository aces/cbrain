
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

#
# This class is exactly like VaultSshDataProvider, but
# it also has the ability to browse a subdirectory named
# after a user when calling provider_list_all(user).
#
class IncomingVaultSshDataProvider < VaultSshDataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def is_browsable?(by_user = nil) #:nodoc:
    return true if by_user.blank? || self.meta[:browse_gid].blank?
    return true if by_user.is_a?(AdminUser) || by_user.id == self.user_id
    by_user.is_member_of_group(self.meta[:browse_gid].to_i)
  end

  # We browse ONLY the user's specific subdir.
  def browse_remote_dir(user=nil) #:nodoc:
    if user
      self.remote_dir + "/#{user.login}"
    else
      self.remote_dir
    end
  end

  def impl_provider_list_all(user = nil) #:nodoc:
    tried_mkdir = false
    begin
      super(user)
    rescue Net::SFTP::StatusException
      raise if tried_mkdir
      tried_mkdir = true
      dir         = self.browse_remote_dir(user)
      mkdir_command = "mkdir #{dir.to_s.bash_escape} >/dev/null 2>&1"
      remote_bash_this(mkdir_command)
      retry
    end
  end
  
  # this returns the category of the data provider -- used in view for admins
  def self.pretty_category_name
    "Incoming Vault Types"
  end

end

