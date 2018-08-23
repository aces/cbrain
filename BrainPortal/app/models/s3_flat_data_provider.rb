
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
class S3FlatDataProvider < DataProvider

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  validates_presence_of :cloud_storage_client_identifier, :cloud_storage_client_token,
                        :cloud_storage_client_bucket_name

  validates :cloud_storage_client_identifier,  length: { is: 20 }
  validates :cloud_storage_client_token,       length: { is: 40 }

  validates :cloud_storage_client_bucket_name, format: {
    with: /\A[A-Za-z0-9][A-Za-z0-9\-.]{1,61}[A-Za-z0-9]\z/, # this is good enough; DP will just crash on bad names
    message: "invalid S3 bucket name, for rules see https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-s3-bucket-naming-requirements.html"
  }

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

  def provider_full_path(userfile)
    #"Bucket: #{s3_connection.bucket} Prefix key: #{userfile.name}"
    userfile.name
  end

  def impl_provider_collection_index(userfile, directory = :all, allowed_types = :regular) #:nodoc:

    prefix = Pathname.new(userfile.name)
    if directory == :all
      s3method = :list_objects_recursive
    else
      s3method = :list_objects_one_level
      prefix = prefix + directory unless directory == '.' || directory == :top
    end

    allowed_types = Array(allowed_types)

    s3_objlist = s3_connection.send(:s3_method,prefix)

    s3_fileinfos = s3_objlist_to_fileinfos(s3_objlist)
                   .reject { |fi| is_excluded?(fi.name) }
                   .select { |fi| allowed_types.include? fi.symbolic_type }

    s3_fileinfos.sort! { |a,b| a.name <=> b.name }
    s3_fileinfos
  end

  def impl_sync_to_cache(userfile) #:nodoc:

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
      if relpath.parent.to_s != '.'
        FileUtils.rmdir(fullpath.parent.to_s, :parents => true) rescue true # Attempt removing as many parents as possible
      end
    end

    # Add files locally. Regular and symlinks are supported.
    to_add.each do |fi|
      relpath  = Pathname.new(fi.name) # "abc" or "abc/def" or "abc/dev/gih.txt", always files or symlinks
      fullpath = localparent + relpath
      if relpath.parent.to_s != '.'
        FileUtils.mkpath fullpath.parent.to_s
      end
      if fi.symbolic_type == :regular
        s3_connection.download_object_to_file(relpath, fullpath.to_s)
        FileUtils.touch( fullpath.to_s, :mtime => fi.mtime, :nocreate => true ) if fi.mtime
      elsif fi.symbolic_type == :symlink
        linkval = s3_connection.download_symlink_value(relpath)
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

  def impl_sync_to_provider(userfile) #:nodoc:

    # Cache area info
    localfull   = cache_full_path(userfile)
    localparent = localfull.parent

    # Figure out what to do
    to_add, to_remove = rsync_emulation(
       cache_recursive_fileinfos(    userfile ),
       provider_recursive_fileinfos( userfile ),
    )

    # Remove files that exist remotely but shouldn't
    adj_keys = s3_fileinfos_to_realkeys(to_remove)
    s3_connection.delete_multiple_objects(adj_keys)

    # Add files remotely. Regular and symlinks are supported.
    to_add.each do |fi|
      relpath  = Pathname.new(fi.name) # "abc" or "abc/def" or "abc/dev/gih.txt", always files or symlinks
      fullpath = localparent + relpath
      if fi.symbolic_type == :symlink
        linkvalue = File.readlink(fullpath.to_s)
        s3_connection.upload_symlink_value_to_object(linkvalue, relpath)
      elsif fi.symbolic_type == :regular
        s3_connection.upload_file_content_to_object(fullpath, relpath)
      elsif fi.symbolic_type == :directory
        s3_connection.upload_subdir_placeholder_to_object(relpath)
      else
        # unknown/unsupported file type?
      end
    end

    true
  end

  def impl_provider_erase(userfile) #:nodoc:
    if userfile.is_a?(SingleFile)
      s3_connection.delete_object(userfile.name)
    else
      to_remove = provider_recursive_fileinfos(userfile)
      adj_keys  = s3_fileinfos_to_realkeys(to_remove)
      s3_connection.delete_multiple_objects(adj_keys)
    end
    true
  end

  def impl_provider_list_all(user=nil) #:nodoc:
    dp_list = s3_connection.list_objects_one_level("") # top level
    s3_objlist_to_fileinfos(dp_list)
  end

  def impl_provider_rename(userfile,newname) #:nodoc:
    return false if s3_connection.get_object_info(newname)
    return false if s3_connection.list_objects_one_level(newname).present?
    if userfile.is_a?(SingleFile)
      s3_connection.rename_object(userfile.name,newname)
    else
      s3_connection.list_objects_recursive(userfile.name).each do |s3obj|
        oldkey = s3obj.key
        newkey = oldkey.starts_with?("#{userfile.name}/") ? (newname + oldkey[userfile.name.size,99999]) : newkey
        s3_connection.rename_object(oldkey,newkey) if newkey != oldkey
      end
    end
    true
  end

  private

  def cache_recursive_fileinfos(userfile)
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

  def provider_recursive_fileinfos(userfile)
    objlist = s3_connection.list_objects_recursive(userfile.name)
    s3_objlist_to_fileinfos(objlist)
  end

  def s3_objlist_to_fileinfos(s3_objlist)
    s3_objlist.map do |objinfo| # S3 obj contains just a bit of info, not a full FileInfo struct
      name,type = s3_connection.real_name_and_symbolic_type(objinfo[:key])
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

  def s3_fileinfos_to_realkeys(s3_fileinfos)
    s3_fileinfos.map do |fi|
      next s3_connection.encode_symlink_key(fi.name) if fi.symbolic_type == :symlink
      next s3_connection.encode_subdir_key(fi.name)  if fi.symbolic_type == :directory
      fi.name
    end
  end

  def rsync_emulation(src_fileinfos,dst_fileinfos)

    # Index of all relative pathnames
    src_idx = src_fileinfos.index_by { |fi| fi.name }
    dst_idx = dst_fileinfos.index_by { |fi| fi.name }

    # Build two lists
    delete_dest = dst_fileinfos.select { |fi| ! src_idx[fi.name] }
    add_dest    = src_fileinfos.select do |src_fi|

      # 1st sanity check: by type
      src_type = src_fi.symbolic_type
      next false if src_type != :regular && src_type != :symlink && src_type != :directory # only these three supported

      # Extract some info we'll reuse often
      name     = src_fi.name
      dst_fi   = dst_idx[name] # matching entry at destination

      # Now let's see whether or not we transfer:
      next true  if ! dst_fi # not at destination? always add these
      next false if src_type == :directory && dst_fi.symbolic_type == :directory # directory already at dest, so skip it
      #next true if src_type != dst_fi.symbolic_type # type mismatch?!?
      next true  if src_fi.size != dst_fi.size # their sizes differ
#puts_green "FILE=#{name} SRC MTIME=#{src_fi.mtime} DST MTIME=#{dst_fi.mtime}" if name =~ /symlink_l1/ # debug
      next true  if (src_fi.mtime.to_i - dst_fi.mtime.to_i).abs > 1 # mtimes differ too much
      false # well it seems the file is the same on both sides; do not add it
    end.compact

    # What to add/update, and what to delete
    return [ add_dest.sort    { |a,b| a.name <=> b.name },
             delete_dest.sort { |a,b| a.name <=> b.name },
           ]
  end

end
