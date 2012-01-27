
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

  def allow_file_owner_change? #:nodoc:
    false
  end

end

