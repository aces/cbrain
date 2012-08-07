
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

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def is_browsable? #:nodoc:
    false
  end

  def allow_file_owner_change? #:nodoc:
    false # nope, because files are stored in subdirectories named after the owner's name.
  end

  def impl_sync_to_provider(userfile) #:nodoc:
    basename = userfile.name
    username = userfile.user.login
    twolevels = cache_subdirs_from_name(basename)
    userdir = Pathname.new(remote_dir) + username
    level1  = userdir                  + twolevels[0]
    level2  = level1                   + twolevels[1]
    mkdir_command = "mkdir #{userdir.to_s.bash_escape} #{level1.to_s.bash_escape} #{level2.to_s.bash_escape} >/dev/null 2>&1"
    remote_bash_this(mkdir_command)
    super(userfile)
  end

  def impl_provider_erase(userfile) #:nodoc:
    basename = userfile.name
    username = userfile.user.login
    twolevels = cache_subdirs_from_name(basename)
    userdir = Pathname.new(remote_dir) + username
    level1  = userdir                  + twolevels[0]
    level2  = level1                   + twolevels[1]
    full    = level2                   + basename
    erase_command = "( rm -rf #{full.to_s.bash_escape};rmdir #{level2.to_s.bash_escape} #{level1.to_s.bash_escape} ) >/dev/null 2>&1"
    remote_bash_this(erase_command)
    true
  end

  def impl_provider_rename(userfile,newname)  #:nodoc:
    oldname   = userfile.name
    username  = userfile.user.login

    old2levs  = cache_subdirs_from_name(oldname)
    oldpath   = Pathname.new(remote_dir) + username + old2levs[0] + old2levs[1] + oldname

    new2levs  = cache_subdirs_from_name(newname)
    newlev1   = Pathname.new(remote_dir) + username + new2levs[0]
    newlev2   = newlev1 + new2levs[1]
    newpath   = newlev2 + newname

    newlev1 = newlev1.to_s
    newlev2 = newlev2.to_s
    oldpath = oldpath.to_s
    newpath = newpath.to_s

    # We should create a nice state machine for the remote rename operations
    Net::SFTP.start(remote_host,remote_user, :port => remote_port, :auth_methods => [ 'publickey' ] ) do |sftp|

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
    owner    = userfile.user.login
    subdirs  = cache_subdirs_from_name(basename)
    Pathname.new(remote_dir) + owner + subdirs[0] + subdirs[1] + basename
  end

end

