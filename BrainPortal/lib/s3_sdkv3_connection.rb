
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

require 'aws-sdk-s3'
require 'fileutils'

# A handler connections to Amazon's S3 service.
class S3Sdkv3Connection

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  SYMLINK_ENDING = "_symlink_s3_object" #:nodoc:
  SUBDIR_ENDING  = "/"  #:nodoc:

  # This value is for old backwards-compatibiliy;
  # objects with this ending are now ignored
  OLD_SUBDIR_ENDING = "-subdir_s3_object" #:nodoc:

  # Sets a logger for the AWS layer (default, STDOUT)
  def self.set_logger(logger=Logger.new(STDOUT))
    Aws.config.update(:logger => logger)
  end

  # This invokes the class method of the same name;
  # it is unfortunately not possible to have separate loggers
  # for different instances of S3Sdkv3Connection
  # because the logger is global to the AWS layer.
  def set_logger(logger=Logger.new(STDOUT))
    self.class.set_logger(logger)
  end

  # Establish a connection handler to S3
  def initialize(access_key, secret_key, bucket_name,
                 region   = "us-east-1",
                 endpoint = nil)

    credentials     = Aws::Credentials.new(access_key,secret_key)

    @bucket_name    = bucket_name

    client_connection = {
      :credentials => credentials,
      :region      => region,
    }
    client_connection[:endpoint] = endpoint     if endpoint.present?
    client_connection[:force_path_style] = true if endpoint.present?

    @client         = Aws::S3::Client.new(client_connection)
    self
  end

  ####################################################################
  # Bucket methods
  ####################################################################

  # Create a bucket on the current connection.
  def create_bucket(bucket_name)
    @client.create_bucket(bucket: bucket_name)
  end

  # Returns true if a particular bucket exists.
  def bucket_exists?(name)
    @client.head_bucket(bucket: name)
    return true
  rescue
    false
  end

  # Returns true if the connection is alive.
  # This is the same as checking if the bucket exists.
  def connected?
    bucket_exists?(@bucket_name)
  end

  ####################################################################
  # Listing objects
  ####################################################################

  # Invokes head_object on the key.
  # Returns the AWS::S3::Types::HeadObjectOutput.
  # Returns nil of the key doesn't exist.
  def get_object_info(key)
    @client.head_object( :bucket => @bucket_name, :key => key )
  rescue
    nil
  end

  # List every single object recursively under a given path.
  # Returns a list of each object. Prefix cannot be blank.
  # The list returned contains fake directory entries for object
  # keys that are longer than the prefix and contains the '/'
  # character later on.
  def list_objects_recursive(prefix)
    list_objects_general(prefix,true) # 'true' means recursive
  end

  # List objects under a particular prefix, but not recursively.
  # Returns a list of each object.
  # The list returned contains fake directory entries for object
  # keys that are longer than the prefix and contains the '/'
  # character later on.
  def list_objects_one_level(prefix)
    list_objects_general(prefix,false) # 'false' means not recursive
  end

  # Returns a list similar to the other list_objects_* methods
  # above, but containing the information for a single object
  # with +key+ .
  def list_single_object(key)
    key  = key.to_s
    info = get_object_info(key)
    return [] unless info
    [
       Aws::S3::Types::Object.new( :key           => key,
                                   :last_modified => info.last_modified,
                                   :size          => info.content_length,
                                 ).freeze
    ]
  end

  private

  def list_objects_general(prefix,recursive=false)

    # prefix must be present IF listing recursively, otherwise
    # we would list all objects in the bucket.
    raise "Prefix cannot be blank." if prefix.to_s.blank? && recursive.present?
    delimiter = recursive.present? ? "" : "/"

    list_of_objects = []
    resp            = { :is_truncated => true }
    cont_token      = nil
    prefix          = prefix.to_s
    prefix         += '/' if prefix.present? && ! prefix.ends_with?('/')

    # To avoid duplication of seen prefixes when doing multiple rounds of fetching keys
    seen_common_prefixes = {}

    # We go through multiple rounds of requests, 1000 entries at a time
    while resp[:is_truncated] do
      resp = @client.list_objects_v2(:bucket              => @bucket_name,
                                     :prefix              => prefix,
                                     :delimiter           => delimiter, # empty string is OK
                                     :continuation_token  => cont_token)
      break if resp.blank?

      # Add cumulatively the list of objects
      current_list_of_obj = resp.contents.presence || []
      current_list_of_obj.reject! { |obj| obj.key == prefix } # any fake subdir object like "a/b/c/" that match exactly the prefix
      current_list_of_obj.reject! { |obj| obj.key.ends_with?(OLD_SUBDIR_ENDING) } # remove old compatibility objects
      list_of_objects += current_list_of_obj # cumulative list

      # Add to the list some artificial objects representing subdirs
      common_prefixes = resp.common_prefixes.presence || []
      common_prefixes.reject! { |obj| seen_common_prefixes[obj.prefix] }
      common_prefixes.each    { |obj| seen_common_prefixes[obj.prefix] = true }
      local_subdir_keys = create_fake_subdir_s3objs(common_prefixes)
      list_of_objects  += local_subdir_keys

      cont_token       = resp[:next_continuation_token]
    end

    list_of_objects
  end

  def create_fake_subdir_s3objs(s3_common_prefixes)
    return [] if s3_common_prefixes.blank? # in case it's nil
    s3_common_prefixes.map(&:prefix).map do |subprefix|
      Aws::S3::Types::Object.new(
        :key           => encode_subdir_key(subprefix),
        :last_modified => Time.now,
        :size          => 0,
      ).freeze
    end.compact
  end

  ####################################################################
  # Object operations
  ####################################################################

  public

  # Basic renaming. This is tricky as objects are fully copied
  # and then the old one with the old name is destroyed.
  def rename_object(oldkey,newkey)
    @client.copy_object( :copy_source => "/#{@bucket_name}/#{oldkey}",
                         :bucket      => @bucket_name,
                         :key         => newkey )
    delete_object(oldkey)
  end

  ####################################################################
  # Normal files I/O
  ####################################################################

  # Uploads a piece of data to an object.
  # If src is anything but a IO, it will be send
  # as-is. If src is a IO, the data read from it will be sent.
  def upload_data_to_object(src, key)
    @client.put_object( bucket: @bucket_name,
                        key:    key.to_s,
                        body:   src,
                      )
  end

  # Upload the content of a file *src*. The file will be
  # opened and sent as an object.
  def upload_file_content_to_object(src, key)
    src = File.open(src.to_s,'r:BINARY') unless src.is_a?(IO)
    upload_data_to_object(src, key)
  end

  # Download the content of an object; if dest
  # is a IO, the content will be streamed to it.
  # Otherwise, dest will be opened as a file in
  # write mode.
  def download_object_to_file(key, dest)
    if dest.is_a?(IO)
      @client.get_object( bucket:          @bucket_name,
                          key:             key.to_s,
                        ) { |chunk| dest.write(chunk) }
    else
      @client.get_object( bucket:          @bucket_name,
                          key:             key.to_s,
                          response_target: dest.to_s,
                        )
    end
  end

  # Delete an object.
  def delete_object(key)
    @client.delete_object( bucket: @bucket_name,
                           key:    key.to_s,
                         )
  end

  # Delete a bunch of object; +keylist+ is an array
  # of all their keys.
  def delete_multiple_objects(keylist)
    keylist.each_slice(999) do |sublist| # we can only do up to 1000 in the S3 API
      @client.delete_objects( bucket: @bucket_name,
                              delete: {
                                        objects: sublist.map { |k| { key: k.to_s } },
                                      },
                            )
    end
  end

  ####################################################################
  # Subdirectory I/O
  ####################################################################

  # This create an empty object with a special name
  # for representing a subdirectory +key+.
  def upload_subdir_placeholder_to_object(key)
    upload_data_to_object("",encode_subdir_key(key))
  end

  ####################################################################
  # Symbolic link I/O
  ####################################################################

  # This create an empty object with a special name
  # for representing a symbolic link named +key+ with +symlinkvalue+ .
  def upload_symlink_value_to_object(symlinkvalue, key)
    upload_data_to_object(symlinkvalue,encode_symlink_key(key))
  end

  # Given a path 'key' representing a symlink, will fetch
  # and return the symlink value.
  def download_symlink_value(key)
    linkvalue = ""
    @client.get_object( bucket: @bucket_name,
                        key:    encode_symlink_key(key),
                      ) { |chunk| linkvalue += chunk }
    linkvalue
  end

  ####################################################################
  # Special renaming methods for symlinks and subdirs
  ####################################################################

  def encode_symlink_key(key) #:nodoc:
    "#{key}#{SYMLINK_ENDING}"
  end

  def decode_symlink_key(symkey) #:nodoc:
    if symkey.to_s.ends_with? SYMLINK_ENDING
      (symkey.to_s)[0..-(SYMLINK_ENDING.size+1)]
    else
      symkey.to_s
    end
  end

  def encode_subdir_key(key) #:nodoc:
    return key if key.to_s.ends_with? SUBDIR_ENDING
    "#{key}#{SUBDIR_ENDING}"
  end

  def decode_subdir_key(subkey) #:nodoc:
    if subkey.to_s.ends_with? SUBDIR_ENDING
      (subkey.to_s)[0..-(SUBDIR_ENDING.size+1)]
    else
      subkey.to_s
    end
  end

  # Given a key that may or may not encode
  # a special naming convention for symbolic links
  # or subdirectories, will return the 'normal'
  # key name (usually looks like a normal path)
  # and a symbol for the encoded type (one of
  # :regular, :directory, or :symlink) as
  # used in DataProvider::FileInfo objects.
  def real_name_and_symbolic_type(key)
    if key.ends_with? SYMLINK_ENDING
      return [ decode_symlink_key(key), :symlink ]
    elsif key.ends_with? SUBDIR_ENDING
      return [ decode_subdir_key(key),  :directory ]
    else
      return [ key, :regular ]
    end
  end

end
