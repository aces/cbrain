
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

# This class provides an implementation for a data provider
# where the remote files are not even remote, they are local
# to the currently running rails application. The provider's
# files are stored in a flat directory, two levels
# deep, directly specified by the object's +remote_dir+
# attribute and the user's login name. The file "hello"
# of user "myuser" is thus stored into a path like this:
#
#     /root_dir/myuser/hello
#
# where +root_dir+ is the data provider's +remote_dir+ (a local
# directory).
#
# This data provider does not cache anything! The 'remote' files
# are in fact all local, and accessing the 'cached' files mean
# accessing the real provider's files. All methods are adjusted
# so that their behavior is sensible.
#
# For the list of API methods, see the DataProvider superclass.
class VaultLocalDataProvider < LocalDataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def cache_prepare(userfile) #:nodoc:
    SyncStatus.ready_to_modify_cache(userfile) do
      username  = userfile.user.login
      userdir = Pathname.new(remote_dir) + username
      Dir.mkdir(userdir) unless File.directory?(userdir)
      true
    end
  end

  def cache_full_path(userfile) #:nodoc:
    basename  = userfile.name
    username  = userfile.user.login
    Pathname.new(remote_dir) + username + basename
  end

  def cache_erase(userfile) #:nodoc:
    SyncStatus.ready_to_modify_cache(userfile,:destroy) do
      true
    end
  end

  def impl_provider_list_all(user=nil) #:nodoc:
    cb_error "This data provider cannot be browsed." unless self.is_browsable?(user)
    super(user)
  end

  def impl_provider_erase(userfile) #:nodoc:
    FileUtils.remove_entry(cache_full_path(userfile), true)
    true
  end

  def impl_provider_rename(userfile,newname) #:nodoc:
    oldpath   = userfile.cache_full_path
    userdir   = oldpath.parent
    newpath   = userdir + newname
    begin
      FileUtils.mv(oldpath.to_s,newpath.to_s, :force => true)
      return true
    rescue
      return false
    end
  end
  
  # this returns the category of the data provider -- used in view for admins
  def self.pretty_category_name
    "Vault Types"
  end

  def impl_provider_report #:nodoc:
    issues    = []
    base_path = Pathname.new(remote_dir)
    users     = User.where({})
    user_dirs = users.raw_rows(:login).flatten

    # Look for files outside user directories
    Dir.foreach(base_path).reject { |f| f.start_with?('.') || user_dirs.include?(f) }.each do |out|
      issues << {
        :type     => :outside,
        :message  => "Unknown file '#{out}' outside user directories",
        :severity => :minor
      }
    end

    # Look for unregistered files in user directories
    users.each do |user|
      next unless File.directory?(base_path + user.login)
      registered = self.userfiles.where(:user_id => user).raw_rows(:name).flatten
      Dir.foreach(base_path + user.login).reject { |f| f.start_with?('.') || registered.include?(f) }.each do |unreg|
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

    issues + super
  end

  def impl_provider_repair(issue) #:nodoc:
    raise "No automatic repair possible. Move or delete the file manually." if issue[:type] == :outside

    super(issue)
  end
end

