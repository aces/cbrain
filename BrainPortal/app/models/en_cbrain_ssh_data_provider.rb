
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

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def is_browsable?(by_user = nil) #:nodoc:
    false
  end

  def allow_file_owner_change? #:nodoc:
    true
  end

  def impl_sync_to_provider(userfile) #:nodoc:
    threelevels = cache_subdirs_from_id(userfile.id)
    userdir = Pathname.new(remote_dir)
    level1  = userdir                  + threelevels[0]
    level2  = level1                   + threelevels[1]
    level3  = level2                   + threelevels[2]
    mkdir_command = "mkdir #{level1.to_s.bash_escape} #{level2.to_s.bash_escape} #{level3.to_s.bash_escape} >/dev/null 2>&1"
    remote_bash_this(mkdir_command)
    super(userfile)
  end

  def impl_provider_erase(userfile) #:nodoc:
    threelevels = cache_subdirs_from_id(userfile.id)
    userdir = Pathname.new(remote_dir)
    level1  = userdir                  + threelevels[0]
    level2  = level1                   + threelevels[1]
    level3  = level2                   + threelevels[2]
    erase_command = "( rm -rf #{level3.to_s.bash_escape} ; rmdir #{level2.to_s.bash_escape} #{level1.to_s.bash_escape} ) >/dev/null 2>&1"
    remote_bash_this(erase_command)
    true
  end

  def impl_provider_rename(userfile,newname)  #:nodoc:
    oldpath   = provider_full_path(userfile)
    oldparent = oldpath.parent
    newpath   = oldparent + newname

    oldpath = oldpath.to_s
    newpath = newpath.to_s

    # We should create a nice state machine for the remote rename operations
    self.master # triggers unlocking the agent
    Net::SFTP.start(remote_host,remote_user, :port => remote_port, :auth_methods => [ 'publickey' ] ) do |sftp|

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
    subdirs  = cache_subdirs_from_id(userfile.id)
    Pathname.new(remote_dir) + subdirs[0] + subdirs[1] + subdirs[2] + basename
  end
  
  # this returns the category of the data provider -- used in view for admins
  def self.pretty_category_name
    "Enhanced CBRAIN Types"
  end

  def impl_provider_report #:nodoc:
    issues         = []
    userfile_paths = self.userfiles.map { |u| [u, self.provider_full_path(u).to_s] }
    all_paths      = remote_bash_this("( find #{remote_dir.bash_escape} -empty -type d; find #{remote_dir.bash_escape} -type f )").split("\n")

    # Make sure all registered files exist
    userfile_paths.reject { |u,p| all_paths.include?(p) }.each do |miss,p|
      issues << {
        :type        => :missing,
        :message     => "Missing userfile '#{miss.name}'",
        :severity    => :major,
        :action      => :destroy,
        :userfile_id => miss.id
      }
    end

    # Search the provider's root directory for unknown directories and/or files
    base_regex     = Regexp.new('^' + Regexp.quote(remote_dir) + '/?')
    (all_paths - userfile_paths.map { |u,p| p }).each do |unk|
      issues << {
        :type      => :unknown,
        :message   => "Unknown file or directory '#{unk.sub(base_regex, '')}'",
        :severity  => :major,
        :action    => :delete,
        :file_path => unk
      }
    end

    issues
  end

  def impl_provider_repair(issue) #:nodoc:
    return super(issue) unless issue[:action] == :delete

    # Remove the file/directory itself
    path = issue[:file_path]
    remote_bash_this("unlink #{path.bash_escape}")
    path = File.dirname(path)

    # List parent all directories up to remote_dir
    dirs = []
    while path != remote_dir
      dirs << path
      path  = File.dirname(path)
    end

    # Remove them with one command
    remote_bash_this("( #{dirs.map { |d| "rmdir #{d.bash_escape}" }.join("; ")} ) >/dev/null 2>&1")
  end

end

