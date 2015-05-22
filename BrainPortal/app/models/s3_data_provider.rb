
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

  attr_accessor :s3_connection
  
  # this returns the category of the data provider -- used in view for admins
  def self.pretty_category_name
    "Other Types"
  end

  # Connects to the S3 service using :cloud_storage_client_identifier and :cloud_storage_client_token;
  # the connection is maintained in a instance variable!
  def init_connection
    @s3_connection = S3Connection.new(self.cloud_storage_client_identifier, self.cloud_storage_client_token)
  end

  # Hardcoded bucket name is "gbrain_{self.name}"
  def bucket_name
    "gbrain_#{self.name}"
  end

  # Mapping between a userfile's name and the name
  # of the S3 file
  def s3_filename(userfile,newname=nil)
    namekey = newname.presence || userfile.name
    ext = userfile.is_a?(FileCollection) ? ".TGZ" : ""
    "#{userfile.id}_#{namekey}#{ext}"
  end

  # Informational: "bucket/s3_filename"
  def provider_full_path(userfile)
    "#{bucket_name}/#{s3_filename(userfile)}"
  end

  # Mapping between S3 filename and CBRAIN's userfile ID and filename.
  def filename_from_s3_filename(s3_filename)
    userfile_id,filename=s3_filename.split('_', 2)
    return [ userfile_id,filename ]
  end

  # Create the bucket on S3
  def create_base_bucket
    init_connection
    @s3_connection.create_bucket(bucket_name)
  end

  def impl_is_alive? #:nodoc:
    init_connection
    @s3_connection.connected?
  rescue
    false
  end

  def is_browsable?(by_user = nil) #:nodoc:
    false
  end

  def allow_file_owner_change? #:nodoc:
    true
  end

  def impl_sync_to_cache(userfile) #:nodoc:
    init_connection  # s3 connection

    mkdir_cache_subdirs(userfile)
    local_full      = cache_full_pathname(userfile)
    remote_filename = s3_filename(userfile)
    dest_fh         = nil

    Dir.chdir(Pathname.new(local_full).parent) do
      if userfile.is_a?(FileCollection)
        dest_fh = IO.popen("tar -xzf -","w:BINARY")
      else
        dest_fh = File.new(local_full,"w:BINARY")
      end
      @s3_connection.s3object.stream(remote_filename, bucket_name) do |chunk|
        dest_fh.write chunk
      end
      dest_fh.close
    end
    true
  ensure
    dest_fh.close rescue true
  end

  # Note: storing FileCollections on S3 is very innefficient:
  # we .tar.gz the entire collection and save it as a single S3 file... :-(
  def impl_sync_to_provider(userfile)
    init_connection  # s3 connection
    create_base_bucket unless @s3_connection.bucket_exists?(bucket_name)

    local_full      = cache_full_pathname(userfile)
    remote_filename = s3_filename(userfile)
    src_fh          = nil
    tmp_tar_file    = "/tmp/s3_tar_#{Process.pid}_#{Time.now.to_i}.tgz"

    Dir.chdir(Pathname.new(local_full).parent) do
      if userfile.is_a?(FileCollection)
        # Amazon does NOT provide chunked streaming.
        # This means that IO.popen and File.popen both fail
        # because they cannot provide a size for the content.
        #src_fh = IO.popen("tar -czf - #{userfile.name.bash_escape}","r:BINARY")
        # So, we have to make a local tarball instead. Hurgh.
        system("tar", "-czf", tmp_tar_file, userfile.name)
        src_fh = File.new(tmp_tar_file, "r:BINARY")
      else
        src_fh = File.new(local_full,"r:BINARY")
      end
      # bucket = @s3_connection.bucket.find(bucket_name)
      @s3_connection.s3object.store(remote_filename, src_fh, bucket_name, :content_type => 'binary/octet-stream')
      src_fh.close
    end
    true
  ensure
    src_fh.close rescue true
    File.unlink(tmp_tar_file) rescue true
  end

  def impl_provider_erase(userfile) #:nodoc:
    init_connection
    @s3_connection.s3object.delete(s3_filename(userfile), bucket_name)
  end

  def impl_provider_rename(userfile,newname) #:nodoc:
    init_connection
    @s3_connection.s3object.rename s3_filename(userfile), s3_filename(userfile,newname), bucket_name
  end

  def impl_provider_list_all(user) #:nodoc:
    raise "Disabled"
  #  init_connection
  #  s3_connection.bucket.find(bucket_name).objects.map do |object|
  #    file               = DataProvider::FileInfo.new()
  #    filename           = filename_from_s3_filename(object.key)[1]
  #    file.name          = filename
  #    file.symbolic_type = :regular
  #    file.mtime         = Time.parse(object.about()["date"]).to_i
  #    file.size          = 0
  #    file
  #  end
  end

end
