
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

  validates_presence_of :cloud_storage_client_identifier, :cloud_storage_client_token
  validates             :cloud_storage_client_identifier, length: { is: 20 }
  validates             :cloud_storage_client_token,      length: { is: 40 }

  # This returns the category of the data provider
  def self.pretty_category_name #:nodoc:
    "Cloud"
  end

  # Connects to the S3 service using :cloud_storage_client_identifier and :cloud_storage_client_token;
  # the connection is maintained in a instance variable!
  # it is not a real connection, because it is acoomplished through rest interfaces,
  # so the connection is never persistent.
  def s3_connection
    return @s3_connection if @s3_connection
    @s3_connection = S3Sdkv3Connection.new(self.cloud_storage_client_identifier,
                                           self.cloud_storage_client_token,
                                           bucket_name(),
                                           nil)
  end

  # Hardcoded bucket name is "gbrain_{self.id}"
  def bucket_name
    "gbrain-#{self.id}"
  end

  # Mapping between a userfile's name and the name
  # of the S3 file
  def s3_filename(userfile,newname=nil)
    namekey = newname.presence || userfile.name
    ext     = userfile.is_a?(FileCollection) ? ".TGZ" : ""
    "#{userfile.id}_#{namekey}#{ext}"
  end

  # Informational: translates to full path on provider
  def provider_full_path(userfile)
    "#{bucket_name}/#{s3_filename(userfile)}"
  end

  # Create the bucket on S3
  def create_base_bucket #:nodoc:
    s3_connection.create_bucket(bucket_name) unless s3_connection.bucket_exists?(bucket_name)
  end

  def impl_is_alive? #:nodoc:
    return false unless s3_connection.connected?
    create_base_bucket
    true
  rescue
    false
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

  def impl_sync_to_cache(userfile) #:nodoc:
    mkdir_cache_subdirs(userfile)
    local_full      = cache_full_pathname(userfile)
    remote_filename = provider_full_path(userfile)
    dest_fh         = nil

    Dir.chdir(Pathname.new(local_full).parent) do
      if userfile.is_a?(FileCollection)
        dest_fh = IO.popen("tar -xzf -","w:BINARY")
      else
        dest_fh = File.new(local_full,"w:BINARY")
      end
      s3_connection.download_object_to_file(remote_filename,dest_fh)
      dest_fh.close
    end
    true
  ensure
    dest_fh.close rescue true
  end

  # Note: storing FileCollections on S3 is very innefficient:
  # we .tar.gz the entire collection and save it as a single S3 file... :-(
  def impl_sync_to_provider(userfile)
    local_full      = cache_full_pathname(userfile)
    remote_filename = provider_full_path(userfile)
    tmp_tar_file    = "/tmp/s3_tar_#{Process.pid}_#{Time.now.to_i}.tgz"
    src_fh          = nil # scoped here for ensure block below

    if userfile.is_a?(FileCollection)
      Dir.chdir(Pathname.new(local_full).parent) do
        # Amazon does NOT provide chunked streaming.
        # This means that IO.popen and File.popen both fail
        # because they cannot provide a size for the content.
        # IO.popen is refused by AWS because it doesn't respond to .size() and .rewind().
        #src_fh = IO.popen("tar -czf - #{userfile.name.bash_escape}","r:BINARY")
        # So, we have to make a local tarball instead. Hurgh.
        system("tar", "-czf", tmp_tar_file, userfile.name)
        src_fh = File.new(tmp_tar_file, "r:BINARY")
      end
    else
      src_fh = File.new(local_full, "r:BINARY")
    end

    # Transfer file content to S3
    s3_connection.upload_file_content_to_object(src_fh,remote_filename)

    true
  ensure # clean up
    src_fh.close rescue true
    File.unlink(tmp_tar_file) rescue true
  end

  def impl_provider_erase(userfile) #:nodoc:
    remote_filename = provider_full_path(userfile)
    s3_connection.delete_object(remote_filename)
  end

  def impl_provider_rename(userfile,newname) #:nodoc:
    old_path   = provider_full_path(userfile)
    remote_dir = old_path.parent
    new_path   = File.join(remote_dir,newname)
    s3_connection.rename_path(old_path,new_path)
  end

  def impl_provider_list_all(user) #:nodoc:
    raise "Disabled"
  end

end
