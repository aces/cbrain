
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
# in a Amazon S3 bucket.
#
# The encoding system tries to use the bucket as a standard file system:
#
# Amazon keys:
#
#   "file1.txt"
#   "dir1/abc.txt"
#   "dir1/subdir/file.txt"
#
# The 'browse' API will see two entries, 'file1' and 'dir1'.
#
# When uploading and downloading file collections, special objects
# are also created to indicate subdirectories and symbolic links.
#
# The syncing code implements an internal 'rsync'-like algorithm
# to try to transfer only files that have changed between Amazon
# and the local cache.
#
# As of Aug 2022 this DP implementation supports the 'browse_path'
# attribute in userfiles (making it a MultiLevel DP) but the
# capability is only turned on in the subclass S3MultiLevelDataProvider.
class S3FlatDataProvider < DataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_presence_of :cloud_storage_client_identifier, :cloud_storage_client_token,
                        :cloud_storage_client_bucket_name

  validates :cloud_storage_client_identifier,  length: { in: 16..128 }
  validates :cloud_storage_client_token,       length: { in: 20..100 }

  validates :cloud_storage_client_bucket_name, format: {
    with: /\A[A-Za-z0-9][A-Za-z0-9\-.]{1,61}[A-Za-z0-9]\z/, # this is good enough; DP will just crash on bad names
    message: "invalid S3 bucket name, for rules see https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-s3-bucket-naming-requirements.html"
  }

  before_save :canonify_path_start

  # This returns the category of the data provider
  def self.pretty_category_name #:nodoc:
    "Cloud"
  end

  # Connects to the S3 service using :cloud_storage_client_identifier and :cloud_storage_client_token;
  # the connection object is maintained in a instance variable.
  def s3_connection
    return @s3_connection if @s3_connection
    @s3_connection = S3Sdkv3Connection.new(self.cloud_storage_client_identifier,
                                           self.cloud_storage_client_token,
                                           self.cloud_storage_client_bucket_name,
                                           self.cloud_storage_region.presence,
                                           self.cloud_storage_endpoint.presence,
                                          )
  end

  def impl_is_alive? #:nodoc:
    return true if s3_connection.connected?
    # Try to create the bucket once
    s3_connection.create_bucket(cloud_storage_client_bucket_name) unless s3_connection.bucket_exists?(cloud_storage_client_bucket_name)
    # Check again
    s3_connection.connected?
  rescue
    false
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

  # Utility method that prefixes +path+ with the value of
  # cloud_storage_client_path_start if it is present.
  # Will try to return an object of the same type as +path+ (e.g.
  # a String or a Pathname)
  #
  # It's important for this method to preserve trailing slashes.
  def add_start(path)
    return path if cloud_storage_client_path_start.blank?
    joined = cloud_storage_client_path_start + "/" + path.to_s
    return Pathname.new(joined) if path.is_a?(Pathname)
    joined
  end

  # The inverse of add_start().
  def remove_start(path)
    return path if cloud_storage_client_path_start.blank?
    return path unless path.to_s.starts_with? "#{cloud_storage_client_path_start}/"
    removed = path.to_s.sub("#{cloud_storage_client_path_start}/","")
    return Pathname.new(removed) if path.is_a?(Pathname)
    removed
  end

  # Returns the relative path of the +userfile+ on the Amazon side.
  def provider_full_path(userfile)
    add_start(userfile.browse_name) # browse_name is "browse_path + / + name"
  end

  # Standard implementation
  def impl_provider_collection_index(userfile, directory = :all, allowed_types = :regular) #:nodoc:

    prefix = Pathname.new(provider_full_path(userfile))
    if directory == :all
      s3method = :list_objects_recursive
    else
      s3method = :list_objects_one_level
      prefix = prefix + directory unless directory == '.' || directory == :top
    end

    allowed_types = Array(allowed_types)

    s3_objlist = s3_connection.send(s3method,prefix)

    s3_fileinfos = s3_objlist_to_fileinfos(s3_objlist, userfile.browse_path)
                   .reject { |fi| is_excluded?(fi.name) }
                   .select { |fi| allowed_types.include? fi.symbolic_type }

    s3_fileinfos.sort! { |a,b| a.name <=> b.name }
    s3_fileinfos
  end

  # Use our own internal rsync-like algorithm.
  def impl_sync_to_cache(userfile) #:nodoc:

    # Intermediate browse_path on S3 side
    provider_browse_path = Pathname.new(userfile.browse_path.presence || "")

    # Prep cache area
    mkdir_cache_subdirs(userfile)
    localfull   = cache_full_path(userfile)
    localparent = localfull.parent

    # Prep one more level for FileCollections
    if userfile.is_a?(FileCollection)
      Dir.mkdir(localfull) unless File.directory?(localfull)
    end

    # Figure out what to do
    to_add, to_remove = rsync_emulation(
      provider_recursive_fileinfos( userfile ),
      cache_recursive_fileinfos(    userfile ),
    )

    # Remove files that exist locally but shouldn't
    to_remove.each do |fi|
      relpath  = Pathname.new(fi.name) # "abc" or "abc/def" or "abc/dev/gih.txt", always files or symlinks
      fullpath = localparent + relpath
      FileUtils.remove_entry(fullpath.to_s, true) rescue true
    end

    # Add files locally. Regular and symlinks are supported.
    to_add.each do |fi|
      relpath      = Pathname.new(fi.name) # "abc" or "abc/def" or "abc/dev/gih.txt", always files or symlinks
      fullpath     = localparent + relpath # dest filepath in filesystem cache
      prov_relpath = provider_browse_path + relpath # "browse/path/abc" or "browse/path/abc/def" etc
      prov_key     = add_start(prov_relpath)
      FileUtils.remove_entry(fullpath.to_s, true) rescue true # destroy whatever is in the way
      if relpath.parent.to_s != '.'
        FileUtils.mkpath fullpath.parent.to_s
      end
      if fi.symbolic_type == :regular
        s3_connection.download_object_to_file(prov_key, fullpath.to_s)
        FileUtils.touch( fullpath.to_s, :mtime => fi.mtime, :nocreate => true ) if fi.mtime
      elsif fi.symbolic_type == :symlink
        linkval = s3_connection.download_symlink_value(prov_key)
        File.unlink(fullpath.to_s) if File.symlink?(fullpath.to_s) # we force re-creation... because can't compare timestamps
        File.symlink(linkval, fullpath.to_s)
        # Prob: it doesn't seem we can restore the mtime for a symlink... maybe this will cause
        # some unnecessary sync up and down, but we don't want to affect the mtime of the
        # the target of the symlink.
      elsif fi.symbolic_type == :directory
        FileUtils.mkpath fullpath.to_s
      else
        # unknown/unsupported file type?
      end
    end

    true
  end

  # Use our own internal rsync-like algorithm.
  def impl_sync_to_provider(userfile) #:nodoc:

    # Intermediate browse_path on S3 side
    provider_browse_path = Pathname.new(userfile.browse_path.presence || "")

    # Cache area info
    localfull   = cache_full_path(userfile)
    localparent = localfull.parent

    # Figure out what to do
    to_add, to_remove = rsync_emulation(
      cache_recursive_fileinfos(    userfile ),
      provider_recursive_fileinfos( userfile ),
    )

    # Remove files that exist remotely but shouldn't
    rem_keys = s3_fileinfos_to_realkeys(to_remove)
    rem_keys = rem_keys.map { |k| add_start((provider_browse_path + k).to_s) }
    s3_connection.delete_multiple_objects(rem_keys)

    # Add files remotely. Regular and symlinks are supported.
    to_add.each do |fi|
      relpath      = Pathname.new(fi.name) # "abc" or "abc/def" or "abc/dev/gih.txt", always files or symlinks
      fullpath     = localparent + relpath  # physical file in local cache
      prov_relpath = provider_browse_path + relpath # "browse/path/abc" or "browse/path/abc/def" etc
      prov_key     = add_start(prov_relpath)
      if fi.symbolic_type == :symlink
        linkvalue = File.readlink(fullpath.to_s)
        s3_connection.upload_symlink_value_to_object(linkvalue, prov_key)
      elsif fi.symbolic_type == :regular
        s3_connection.upload_file_content_to_object(fullpath, prov_key)
      elsif fi.symbolic_type == :directory
        s3_connection.upload_subdir_placeholder_to_object(prov_key)
      else
        # unknown/unsupported file type?
      end
    end

    true
  end

  def impl_provider_erase(userfile) #:nodoc:
    if userfile.is_a?(SingleFile)
      s3_connection.delete_object(provider_full_path(userfile))
    else
      # Intermediate browse_path on S3 side
      provider_browse_path = Pathname.new(userfile.browse_path.presence || "")
      to_remove = provider_recursive_fileinfos(userfile)
      rem_keys  = s3_fileinfos_to_realkeys(to_remove)
      rem_keys  = rem_keys.map { |k| add_start((provider_browse_path + k).to_s) }
      s3_connection.delete_multiple_objects(rem_keys)
    end
    true
  end

  def impl_provider_list_all(user=nil, browse_path=nil) #:nodoc:
    dp_list = s3_connection.list_objects_one_level(add_start(browse_path.presence || "")) # top level
    s3_objlist_to_fileinfos(dp_list, browse_path)
  end

  def impl_provider_rename(userfile, newname) #:nodoc:

    # Intermediate browse_path on S3 side
    provider_browse_path = Pathname.new(userfile.browse_path.presence || "")
    prov_newname         = (provider_browse_path + newname).to_s
    prov_newkey          = add_start(prov_newname)

    return false if s3_connection.get_object_info(prov_newkey)
    return false if s3_connection.list_objects_one_level(prov_newkey).present?
    if userfile.is_a?(SingleFile)
      s3_connection.rename_object(provider_full_path(userfile),prov_newkey)
    else
      s3_connection.list_objects_recursive(provider_full_path(userfile)).each do |s3obj|
        oldkey = s3obj.key
        next unless oldkey.starts_with?("#{provider_full_path(userfile)}/")
        newkey = oldkey.sub("#{provider_full_path(userfile)}/","#{prov_newkey}/")
        s3_connection.rename_object(oldkey,newkey)
      end
    end
    true
  end

  private

  # Scan the local cache and returns a list of FileInfo objects
  # descriving all the files and directories.
  def cache_recursive_fileinfos(userfile) #:nodoc:
    cache_fullpath = userfile.cache_full_path
    cache_parent   = cache_fullpath.parent
    parent_length  = "#{cache_parent}/".length # used in substr below
    glob_pattern   = userfile.is_a?(FileCollection) ? "/**/*" : ""
    Dir.glob("#{userfile.cache_full_path}#{glob_pattern}").map do |fullpath|   # /path/to/userfilebase/d1/d2/f1.txt
      stats   = File.lstat(fullpath) # not stat() !
      relpath = fullpath[parent_length,999999]                # userfilebase/d1/d2/f1.txt
      # This struct is defined in DataProvider
      FileInfo.new(
        :name          => relpath,
        :symbolic_type => (stats.directory? ? :directory :
                          (stats.symlink?   ? :symlink   :
                          (stats.file?      ? :regular   :
                                              :unknown   ))),
        :size          => stats.size,
        :permissions   => stats.mode, # not used
        :uid           => stats.uid,
        :gid           => stats.gid,
        # (Not filling :owner and :group here)
        :atime         => stats.atime,
        :ctime         => stats.ctime,
        :mtime         => stats.mtime,
      )
    end.compact # the compact is in case we ever insert a 'next' in the map() above
  end

  # Scan the Amazon bucket and returns a list of FileInfo objects
  # descriving all the files and directories inside a userfile
  # (if a FileCollection) or describing the single entry (if a SingleFile).
  def provider_recursive_fileinfos(userfile)
    single_head = s3_connection.list_single_object(provider_full_path(userfile))
    objlist     = s3_connection.list_objects_recursive(provider_full_path(userfile))
    s3_objlist_to_fileinfos(single_head + objlist, userfile.browse_path)
  end

  private

  # Before save callback. The client start path needs to be
  # nil, or a relative path such as 'a/b/c' with no leading slash.
  def canonify_path_start
    start = (self.cloud_storage_client_path_start.presence || "")
      .strip
      .sub(/\A\//,"") # remove leading /
      .sub(/\/\z/,"") # remove trailing /
      .strip
    self.cloud_storage_client_path_start = start.presence
    true
  end

  # Turns an array of objects infos built on the Amazon side
  # into an array of FileInfo objects.
  def s3_objlist_to_fileinfos(s3_objlist, remove_browse_path) #:nodoc:
    remove_bp_slash = remove_browse_path.sub(/\/*$/,"/") if remove_browse_path.present? # adds a '/' at end
    s3_objlist.map do |objinfo| # S3 obj contains just a bit of info, not a full FileInfo struct
      name, type = s3_connection.real_name_and_symbolic_type(objinfo[:key])
      name       = remove_start(name)
      name       = name.sub(remove_bp_slash, "") if remove_bp_slash
      FileInfo.new(
        :name          => name,
        :symbolic_type => type,
        :mtime         => objinfo[:last_modified],
        :atime         => objinfo[:last_modified], # no separate a and c times
        :ctime         => objinfo[:last_modified],
        :size          => objinfo[:size],
      )
    end
  end

  # Turns an array of FileInfo objects representing S3 objects
  # into an array of S3 key names (with special encoding
  # for symlinks and directories if necessary).
  def s3_fileinfos_to_realkeys(s3_fileinfos) #:nodoc:
    s3_fileinfos.map do |fi|
      next s3_connection.encode_symlink_key(fi.name) if fi.symbolic_type == :symlink
      next s3_connection.encode_subdir_key(fi.name)  if fi.symbolic_type == :directory
      fi.name
    end
  end

  # Given to arrays of FileInfo objects, produces two
  # list of things to do to synchronize the source at
  # the destination:
  #  - a list of FileInfo objects for things to remove
  #    at the destination.
  #  - a list of FileInfo objects for things in the source
  #    to copy to the destination.
  def rsync_emulation(src_fileinfos,dst_fileinfos) #:nodoc:

    # Index of all relative pathnames
    src_idx = src_fileinfos.index_by { |fi| fi.name }
    dst_idx = dst_fileinfos.index_by { |fi| fi.name }

    # Hash of all possible directory prefixes at source
    all_src_prefixes = src_idx
      .keys  # names of all source files and dirs
      .map { |path| File.dirname(path) }  # parents of all of them
      .uniq
      .map do |dirpath|
        prefixes = [ dirpath ]
        while (parent=File.dirname(dirpath)) != '.'
          raise "Woh, got an absolute path back to root filesystem?!?" if parent == '/'
          prefixes << parent
          dirpath   = parent
        end
        prefixes
      end
      .flatten
      .index_by(&:itself) # will also do uniq

    # Build two lists
    delete_dest  = dst_fileinfos.select { |fi| ! src_idx[fi.name] && ! all_src_prefixes[fi.name] }
    delete_dest += dst_fileinfos.select { |fi| src_idx[fi.name] && src_idx[fi.name].symbolic_type != fi.symbolic_type }
    add_dest     = src_fileinfos.select do |src_fi|

      # 1st sanity check: by type
      src_type = src_fi.symbolic_type
      next false if src_type != :regular && src_type != :symlink && src_type != :directory # only these three supported

      # Extract some info we'll reuse often
      name     = src_fi.name
      dst_fi   = dst_idx[name] # matching entry at destination

      # Now let's see whether or not we transfer:
      next true  if ! dst_fi # not at destination? always add these
      next false if src_type == :directory && dst_fi.symbolic_type == :directory # directory already at dest, so skip it
      next true  if src_type != dst_fi.symbolic_type # type mismatch?!?
      next true  if src_fi.size != dst_fi.size # their sizes differ
      next true  if (src_fi.mtime.to_i - dst_fi.mtime.to_i).abs > 1 # mtimes differ too much
      false # well it seems the file is the same on both sides; do not add it
    end.compact

    # What to add/update, and what to delete
    return [ add_dest.sort    { |a,b| a.name <=> b.name },
             delete_dest.sort { |a,b| a.name <=> b.name },
           ]
  end

end
