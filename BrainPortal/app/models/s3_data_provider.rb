
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

# Implements a DataProvider that stores its files
# in a Amazon S3 bucket. Single files are saved
# as-is, FileCollections are tar'ed and untar'ed
# as needed.
class S3DataProvider < DataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_presence_of :cloud_storage_client_identifier, :cloud_storage_client_token,
                        :cloud_storage_client_path_start, :cloud_storage_client_bucket_name

  attr_accessor :s3_connection

  # This returns the category of the data provider
  def self.pretty_category_name #:nodoc:
    "Cloud"
  end

  # Connects to the S3 service using :cloud_storage_client_identifier and :cloud_storage_client_token;
  # the connection is maintained in a instance variable!
  def init_connection
    @s3_connection = S3Connection.new(self.cloud_storage_client_identifier,
                                      self.cloud_storage_client_token,
                                      self.cloud_storage_client_bucket_name,
                                      self.cloud_storage_client_path_start)
  end

  # Get the bucket name for the Data Provider specified at creation
  def bucket_name
    @s3_connection.bucket_name
  end

  def impl_is_alive? #:nodoc:
    init_connection
    @s3_connection.connected?
  end

  def is_browsable?(by_user = nil) #:nodoc:
    return true if by_user.blank? || self.meta[:browse_gid].blank?
    return true if by_user.is_a?(AdminUser) || by_user.id == self.user_id
    by_user.is_member_of_group(self.meta[:browse_gid].to_i)
  end

  def allow_file_owner_change? #:nodoc:
    true
  end

  def content_storage_shared_between_users? #:nodoc:
    true
  end

  def provider_full_path(userfile)
    init_connection
    @s3_connection.clean_starting_folder_path(userfile.name)
  end

  def impl_provider_collection_index(userfile, directory = :all, allowed_types = :regular) #:nodoc:
    list = []
    types = allowed_types.is_a?(Array) ? allowed_types.dup : [allowed_types]
    types.map!(&:to_sym)

    init_connection
    entries = []
    if userfile.is_a? FileCollection
      if directory == :all
        entriesTmp = s3_connection.list_objects_long(userfile.name)
        entriesTmp.each do |e|
          x = @s3_connection.get_object_stats(e[:key])
          x[:name] = e[:key]
          entries << x
        end
      else
        if directory == :top or directory == "."# Think this indicates the whole bucket
          entriesTmp = s3_connection.list_objects_short(userfile.name.to_s + "/")
          directory_to_pass = ""
        else
          full_dir_name = File.join(userfile.name.to_s,directory).to_s + "/"
          entriesTmp = s3_connection.list_objects_short(full_dir_name)
          directory_to_pass = directory
        end
        fullPath = entriesTmp[:path]
        entriesTmp[:files].each do |e|
          fname = fullPath.to_s + e[:name]
          entry = @s3_connection.get_object_stats(fname)
          entry[:name] = directory_to_pass != "" ? File.join(directory_to_pass,e[:name]).to_s : e[:name]
          entries << entry
        end
        entriesTmp[:folders].each do |d|
          fname = fullPath.to_s + d[:name]
          date_and_size = @s3_connection.get_mod_date_and_size_for_folder(fname)
          entry = {:name => directory_to_pass != "" ? File.join(directory_to_pass,d[:name]).to_s : d[:name],
                   :last_modified => date_and_size[:last_modified],
                   :content_length => date_and_size[:content_length],
                   :content_type => "application/x-directory"}
          entries << entry
        end
      end
    else
      entry = @s3_connection.get_object_stats(provider_full_path(userfile))
      entry[:name] = userfile.name
      entries << entry
    end

    entries.each do |entry|
      type = @s3_connection.translate_content_type_to_ftype(entry[:content_type])
      next unless types.include?(type)
      next if is_excluded?(entry[:name]) # in DataProvider

      fileinfo = FileInfo.new
      fileinfo.name          = entry[:name]
      fileinfo.symbolic_type = type
      fileinfo.size          = entry[:content_length]
      fileinfo.mtime         = entry[:last_modified]
      fileinfo.owner         = "s3"
      fileinfo.group         = "s3"
      list << fileinfo
   end
   list.sort! { |a,b| a.name <=> b.name }
   list
 end

  def impl_sync_to_cache(userfile) #:nodoc:
    init_connection  # s3 connection
    localfull = cache_full_path(userfile)
    remotefull = provider_full_path(userfile)
    mkdir_cache_subdirs(userfile)
    if userfile.is_a?(FileCollection)
      Dir.mkdir(localfull) unless File.directory?(localfull)
      # implement streaming in here
      @s3_connection.copy_path_from_bucket(remotefull,localfull)
    else
      @s3_connection.copy_object_from_bucket(remotefull,localfull)
    end
  end

  def impl_sync_to_provider(userfile) #:nodoc:
    init_connection  # s3 connection
    localfull      = cache_full_pathname(userfile)
    remotefilename = provider_full_path(userfile)

    cb_error "Error: file #{localfull} does not exist in local cache" unless File.exists?(localfull)
    if userfile.is_a?(FileCollection)
      @s3_connection.copy_directory_to_bucket(localfull.to_s,File.dirname(remotefilename))
    else
      @s3_connection.copy_file_to_bucket(localfull.to_s,File.dirname(remotefilename))
    end
  end

  def impl_provider_erase(userfile) #:nodoc:
    init_connection

    remotefilename = provider_full_path(userfile)
    @s3_connection.delete_path_from_bucket(remotefilename)
  end

  def impl_provider_rename(userfile,newname) #:nodoc:
    init_connection

    oldpath = provider_full_path(userfile)
    remotedir = oldpath.parent
    newpath = File.join(remotedir,newname)

    if userfile.is_a?(FileCollection)
      begin
        @s3_connection.rename_path(oldpath,newpath)
        return true
      rescue
        return false
      end
    else
      begin
        @s3_connection.rename_object(oldpath,newpath)
        return true
      rescue
        return false
      end
    end
  end

  def impl_provider_list_all(user=nil) #:nodoc:

    init_connection
    fileData = @s3_connection.list_objects_short()
    list = []

    # First parse the files
    fileData[:files].each do |f|
      next if is_excluded?(f[:name])

      #Adjust type (always a file here)
      type = :regular

      # Create a FileInfo
      fileinfo               = FileInfo.new
      fileinfo.name          = f[:name]
      fileinfo.symbolic_type = type
      fileinfo.size          = f[:size]
      fileinfo.mtime         = f[:time]
      fileinfo.owner         = "s3"
      fileinfo.group         = "s3"

      list << fileinfo
    end

    ## Now the folders
    fileData[:folders].each do |d|
      next if is_excluded?(d[:name])

      #Adjust type (always a folder here)
      type = :directory

      fileinfo               = FileInfo.new
      fileinfo.name          = d[:name]
      fileinfo.symbolic_type = type
      fileinfo.size          = 0
      fileinfo.mtime         = nil
      fileinfo.owner         = "s3"
      fileinfo.group         = "s3"

      list << fileinfo
    end
    list.sort! { |a,b| a.name <=> b.name }
    list
  end

  def impl_provider_report #:nodoc:
    init_connection

    issues       = []

    ## Check for missing objects
    self.userfiles.each do |uf|
      next if @s3_connection.object_exists?(uf.name)
      issues << {
        :type        => :missing,
        :message     => "Missing userfile '#{uf.name}'",
        :severity    => :major,
        :action      => :destroy,
        :userfile_id => uf.id
      }
    end
    ## Check for unregistered objects
    remote_files = @s3_connection.list_objects_short()

    userfile_names = self.userfiles.collect { |u| u.name }
    unreg = []
    remote_files[:files].each do |rf|
      next if userfile_names.include?(rf[:name])
      unreg << rf
    end
    remote_files[:folders].each do |rf|
      next if userfile_names.include?(rf[:name])
      unreg << rf
    end

    unreg.each do |uf|
      issues << {
        :type     => :unregistered,
        :message  => "Unregistered file '#{uf[:name]}'",
        :severity => :trivial
      }
    end
    issues
  end

  ## Really, nothing to do here
  def impl_provider_repair(issue) #:nodoc:
    return super(issue) unless issue[:action] == :delete
  end
end
