
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

  Revision_info=CbrainFileRevision[__FILE__]

  def is_browsable? #:nodoc:
    false
  end

  def allow_file_owner_change? #:nodoc:
    false # nope, because files are stored in subdirectories named after the owner's name.
  end

  def impl_sync_to_provider(userfile) #:nodoc:
    username = userfile.user.login
    userdir = Pathname.new(remote_dir) + username
    mkdir_command = "mkdir #{userdir.to_s.bash_escape} >/dev/null 2>&1"
    remote_bash_this(mkdir_command)
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

