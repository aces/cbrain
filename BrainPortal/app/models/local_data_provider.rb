
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
# This this is an abstract class which represents data providers
# where the remote files are not even remote, they are local
# to the currently running rails application.
#
# Subclasses are not meant to cache anything! The 'remote' files
# are in fact all local, and accessing the 'cached' files means
# accessing the real provider's files. All methods are adjusted
# so that their behavior is sensible.
#
# Not all API methods are defined here so this class is not meant
# to be instantiated directly.
#
# For the list of API methods, see the DataProvider superclass.
class LocalDataProvider < DataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  cbrain_abstract_model! # objects of this class are not to be instantiated

  # This returns the category of the data provider -- used in view for admins
  # Returning a nil is the convention that we'll use to HIDE a data provider class from the interface.
  # So we'll return nil if the data_provider class is not appriopriate for the users to view
  def self.pretty_category_name #:nodoc:
    nil
  end

  def is_browsable?(by_user = nil) #:nodoc:
    false
  end

  def allow_file_owner_change? #:nodoc:
    true
  end

  def content_storage_shared_between_users? #:nodoc:
    false
  end

  # Returns true: local data providers are considered fast syncing.
  def is_fast_syncing?
    true
  end

  # The remote dir is actually a local directory here.
  def browse_remote_dir(user=nil) #:nodoc:
    self.remote_dir
  end

  def provider_full_path(userfile) #:nodoc:
    self.cache_full_path(userfile)
  end

  def impl_is_alive? #:nodoc:
    return true if File.directory?(remote_dir)
    false
  end

  def impl_sync_to_cache(userfile) #:nodoc:
    true
  end

  def impl_sync_to_provider(userfile) #:nodoc:
    true
  end

  def impl_provider_erase(userfile)  #:nodoc:
    fullpath = cache_full_path(userfile) # actually real path on DP
    begin
      FileUtils.remove_entry(fullpath.to_s, true)
    rescue Errno::ENOENT, Errno::ENOTEMPTY
      # It's OK if any of the rmdir fails, and we simply ignore that.
    end
    true
  end

  def impl_provider_rename(userfile,newname)  #:nodoc:
    oldpath   = cache_full_path(userfile)
    oldparent = oldpath.parent
    newpath   = oldparent + newname
    return false unless FileUtils.move(oldpath.to_s,newpath.to_s)
    true
  end

  def impl_provider_list_all(user=nil) #:nodoc:
    list         = []

    uid_to_owner = {}
    gid_to_group = {}
    Dir.foreach(self.browse_remote_dir(user)) do |name|
      next if name == "." || name == ".."
      next if is_excluded?(name) # in DataProvider

      # Extract information about the entry
      full_path = "#{self.browse_remote_dir(user)}/#{name}"
      stat = File.stat(full_path) rescue nil
      next unless stat # In case the file has been deleted

      # Adjust type
      type =  type = stat.ftype.to_sym
      type = :regular if type == :file
      next if type != :regular && type != :directory && type != :symlink

      # Look up user name from uid
      uid        = stat.uid
      owner_name = (uid_to_owner[uid] ||= (Etc.getpwuid(uid).name rescue uid.to_s))

      # Lookup group name from gid
      gid        = stat.gid
      group_name = (gid_to_group[gid] ||= (Etc.getgrgid(gid).name rescue gid.to_s))

      # Create a FileInfo
      fileinfo               = FileInfo.new
      fileinfo.name          = name
      fileinfo.symbolic_type = type
      fileinfo.size          = stat.size
      fileinfo.permissions   = stat.mode
      fileinfo.atime         = stat.atime
      fileinfo.ctime         = stat.ctime
      fileinfo.mtime         = stat.mtime
      fileinfo.uid           = uid
      fileinfo.owner         = owner_name
      fileinfo.gid           = gid
      fileinfo.group         = group_name

      list << fileinfo
    end

    list.sort! { |a,b| a.name <=> b.name }
    list
  end

  # Redirects the call to cache_readhandle()
  def provider_readhandle(userfile, *args, &block) #:nodoc:
    self.cache_readhandle(userfile, *args, &block)
  end

  def impl_provider_collection_index(userfile, directory = :all, allowed_types = :regular) #:nodoc:
    self.cache_collection_index(userfile, directory, allowed_types)
  end

  def impl_provider_report #:nodoc:
    issues = []

    # Make sure all registered files exist
    self.userfiles.all.select { |u| ! File.exists?(self.provider_full_path(u)) }.each do |miss|
      issues << {
        :type        => :missing,
        :message     => "Userfile '#{miss.name}'",
        :severity    => :major,
        :action      => :destroy,
        :userfile_id => miss.id,
        :user_id     => miss.user_id
      }
    end

    issues
  end

  # Returns the real path on the DP, since there is no caching here.
  def cache_full_path(userfile)
    Pathname.new(remote_dir) + userfile.name
  end

  # We need to override this to not do anything.
  def cache_prepare(userfile) #:nodoc:
    SyncStatus.ready_to_modify_cache(userfile) do
      true
    end
  end

  # Will actually not do anything except record that all is 'fine' with the SyncStatus entry of the file.
  def cache_erase(userfile)
    SyncStatus.ready_to_modify_cache(userfile,:destroy) do
      true
    end
  end

end

