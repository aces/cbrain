
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

  # this returns the category of the data provider -- used in view for admins
  # Returning a nil is the convention that we'll use to HIDE a data provider class from the interface.
  # So we'll return nil if the data_provider class is not appriopriate for the users to view
  def self.pretty_category_name
    nil
  end
  
  # Returns true: local data providers are considered fast syncing.
  def is_fast_syncing?
    true
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
        :message     => "Missing userfile '#{miss.name}'",
        :severity    => :major,
        :action      => :destroy,
        :userfile_id => miss.id
      }
    end

    issues
  end

  protected

  # This method intercepts any attempts to use the protected
  # method used by the caching system. Typically, this would
  # be the result of a bad subclass implementation.
  def mkdir_cache_subdirs(userfile) #:nodoc:
    cb_error "No caching in this provider!"
  end

  # This method intercepts any attempts to use the protected
  # method used by the caching system. Typically, this would
  # be the result of a bad subclass implementation.
  def cache_subdirs_path(userfile) #:nodoc:
    cb_error "No caching in this provider!"
  end

  # This method intercepts any attempts to use the protected
  # method used by the caching system. Typically, this would
  # be the result of a bad subclass implementation.
  def cache_full_dirname(userfile) #:nodoc:
    cb_error "No caching in this provider!"
  end

  # This method intercepts any attempts to use the protected
  # method used by the caching system. Typically, this would
  # be the result of a bad subclass implementation.
  def cache_full_pathname(userfile) #:nodoc:
    cb_error "No caching in this provider!"
  end

end

