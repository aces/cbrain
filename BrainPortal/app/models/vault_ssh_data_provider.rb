
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

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def is_browsable?(by_user = nil) #:nodoc:
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
    cb_error "This data provider cannot be browsed." unless self.is_browsable?(user)
    super(user)
  end

  def impl_provider_report #:nodoc:
    issues    = []
    base_path = Pathname.new(remote_dir)
    users     = User.where({})
    user_dirs = users.raw_rows(:login).flatten

    # Look for files outside user directories
    self.remote_dir_entries(remote_dir).map(&:name).reject { |f| user_dirs.include? f }.each do |out|
      issues << {
        :type     => :outside,
        :message  => "Unknown file '#{out}' outside user directories",
        :severity => :minor
      }
    end

    users.each do |user|
      remote_files = self.remote_dir_entries((base_path + user.login).to_s).map(&:name) rescue []
      registered   = self.userfiles.where(:user_id => user).raw_rows(:id, :name)

      # Make sure all registered files exist
      registered.reject { |i,n| remote_files.include? n }.each do |id,name|
        issues << {
          :type        => :vault_missing,
          :message     => "Missing userfile '#{name}'",
          :severity    => :major,
          :action      => :destroy,
          :userfile_id => id
        }
      end

      # Look for unregistered files in user directories
      registered.map! { |i,n| n }
      remote_files.reject { |f| registered.include?(f) }.each do |unreg|
        issues << {
          :type      => :vault_unregistered,
          :message   => "Unregisted file '#{unreg}' for user '#{user.login}'",
          :severity  => :trivial,
          :action    => :register,
          :user_id   => user.id,
          :file_name => unreg
        }
      end
    end

    issues
  end

  def impl_provider_repair(issue) #:nodoc:
    raise "No automatic repair possible. Move or delete the file manually." if issue[:type] == :outside

    super(issue)
  end

  # This method overrides the method in the immediate
  # superclass SshDataProvider
  def provider_full_path(userfile) #:nodoc:
    basename = userfile.name
    username = userfile.user.login
    Pathname.new(remote_dir) + username + basename
  end
  
  # this returns the category of the data provider -- used in view for admins
  def self.pretty_category_name
    "Vault Types"
  end

end

