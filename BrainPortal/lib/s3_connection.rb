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
class S3Connection

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  attr_accessor :resource, :bucket_name, :path_name, :region

  # Establish a connection handler to S3
  def initialize(access_key, secret_key, bucket_name, path_start, 
                 region='us-east-2',
                 endpoint="http://s3.us-east-2.amazonaws.com")
    credentials = Aws::Credentials.new(access_key,secret_key)
    @bucket_name = bucket_name
    @region = region
    @client = Aws::S3::Client.new(credentials: credentials,
                                  region: @region,
                                  endpoint: endpoint)
    @resource = Aws::S3::Resource.new(client: @client)
    @bucket = @resource.bucket(@bucket_name)
    @path_name = path_start
    @endpoint = endpoint
  end
  
  # Method to translate Mime types to File types
  # Redo more generally
  def translate_content_type_to_ftype(ct)
    ct == "application/x-directory" ? :directory : :regular
  end
      
  # Method to ensure that the paths sent start in the right place
  def clean_starting_folder_path(path)
    path_end = path
    
    if not path_end.to_s.starts_with? @path_name
      return Pathname.new(File.join(@path_name, path_end))
    else
      return Pathname.new(path_end)
    end
  end
  
  def execute_on_s3 #:nodoc:
     yield self
  end

  # Create a bucket on the current connection. Not used, included for completeness
  def self.create_bucket(bucket_name)
    @bucket.create(bucket_name)
  end

  # Returns true if the connection is alive
  # Need to figure out how to return the actual error message so that one can debug
  def connected?
    begin
      testVar = @resource.client.list_objects(bucket: @bucket_name, delimiter: "/")
      return true 
    rescue 
      return false
    end
  end

  # Lists all objects by name only directly undder a given path
  # Returns a hash with files, folders and full path
  # If path is nil, then it uses only the start_path
  def list_objects_short(path=nil)
    path = @path_name + "/" if path.nil?
    
    pathClean = clean_starting_folder_path(path).to_s
    if object_exists?(pathClean)
      contKey = ""
      resp = @resource.client.list_objects_v2(bucket: @bucket_name, 
                                              prefix: pathClean, 
                                              delimiter: "/")
                                               
      filenames = resp.contents.map { |x| {:name => x.key.split("/")[-1],
                                           :time => x.last_modified,
                                           :size => x.size,
                                           :content_type => 'none'} if x.size > 0}.compact
      filenames.each do |x|
        new_key = File.join(pathClean,x[:name])
        respH = @resource.client.head_object({bucket: @bucket_name, key: new_key})
        x[:content_type] = respH.content_type
      end
      folderNames = resp.common_prefixes.map { |x| {:name => x.prefix.split("/")[-1]} }      
      return {:path => pathClean, :files => filenames, :folders => folderNames}                                   
     else
      return {:path => pathClean, :files => [], :folders => []} 
    end
  end
  
  # List every single object recursively under a given path
  # returns a list of each object
  def list_objects_long(path=nil)
    path = @path_name if path.nil?
    
    pathClean = clean_starting_folder_path(path).to_s
    list_of_objects = Array.new()
    
    if object_exists?(pathClean)
      cont_token = nil
      while true
        if cont_token.nil?
          resp = @resource.client.list_objects_v2(bucket: @bucket_name,
                                                  prefix: pathClean).to_h
        else
          resp = @resource.client.list_objects_v2(bucket: @bucket_name,
                                                  prefix: pathClean,
                                                  continuation_token: cont_token).to_h
        end
        
        resp[:contents].each do |x|
          list_of_objects.insert(-1,x)
        end
        
        if resp[:is_truncated] == true
          cont_token = resp[:next_continuation_token]
        else
          break
        end
      end
    end
    return list_of_objects
  end
  
  # Gets the object status of a given path, useful to find out whether a directory or an actual file
  def get_object_stats(objPath)
    if object_exists?(objPath)
      return @resource.client.head_object(bucket: @bucket_name,
                                          key: objPath.to_s).to_h                            
    else
      return {}
    end
  end                                            
      
  # Copies an individual object from S3 back to a destination
  def copy_object_from_bucket(srcObj,dest)
    if object_exists?(srcObj)
      resp = @resource.client.get_object(response_target: dest.to_s,
                                        bucket: @bucket_name,
                                        key: srcObj.to_s)
    end
  end
  
  
  # Copies and sets up all of the directories to copy an entire path from S3 to dest
  def copy_path_from_bucket(path, dest_head)
    if object_exists?(path)
      list_of_objects = list_objects_long(path)
      list_of_objects.each do |x|
        xStat = get_object_stats(x[:key])
        next if xStat[:content_type] == 'application/x-directory'
        trun_object_key = x[:key].dup.sub! "#{clean_starting_folder_path(File.dirname(path).to_s).to_s}/",''
        fullDirName = File.join(dest_head,File.dirname(trun_object_key))
        fullPathName = File.join(dest_head,trun_object_key)
        FileUtils::mkdir_p fullDirName
        copy_object_from_bucket(x[:key], fullPathName)
      end
    end
  end
  
  # Copies a file to the bucket
  def copy_file_to_bucket(srcFile, dest_head)
    trun_object_key = File.basename(srcFile)
    keyPath = File.join(dest_head,trun_object_key).to_s
    resp = @resource.client.put_object(body: srcFile,
                                       bucket: @bucket_name,
                                       key: keyPath)
  end
  
  # Copies a directory to the bucket, will recursively create directory in the path
  def copy_directory_to_bucket(srcDir, dest_head)
    if object_exists?(dest_head)
      Dir.glob("#{srcDir}/**/*").each do |x|
        next if File.directory?(x)
        newDirName = "#{File.dirname(x).sub(File.dirname(srcDir),'')}"
        new_dest_path = File.join(clean_starting_folder_path(dest_head).to_s,newDirName)
        copy_file_to_bucket(x,new_dest_path)
      end
    end
  end

  # Delete an object from the bucket
  def delete_path_from_bucket(path)
    path_clean = clean_starting_folder_path(path).to_s
    if object_exists?(path_clean)
      @resource.bucket(@bucket_name).objects({prefix: path_clean}).batch_delete!
    end
  end
  
  # Renames an objects path
  def rename_object(srcPath,destPath)
    src_path_clean = clean_starting_folder_path(srcPath).to_s
    dest_path_clean = clean_starting_folder_path(destPath).to_s
    if object_exists?(src_path_clean)
      src_path_w_bucket = "/#{File.join(@bucket_name,src_path_clean)}"
      resp = @resource.client.copy_object(bucket:@bucket_name,
                                          copy_source: src_path_w_bucket,
                                          key: dest_path_clean)
      delete_path_from_bucket(src_path_clean)
    end
  end
  
  # Renames a Folder by renaming each object underneath
  def rename_path(srcPath,destPath)
    src_path_clean = clean_starting_folder_path(srcPath).to_s
    dest_path_clean = clean_starting_folder_path(destPath).to_s
    
    if object_exists?(src_path_clean)
      listObjects = list_objects_long(src_path_clean)
  
      listObjects.each do |x|
        xStat = get_object_stats(x[:key])
        next if xStat[:content_type] == 'application/x-directory'
        mod_dest_path = x[:key].dup.sub! src_path_clean,dest_path_clean
        rename_object(x[:key],mod_dest_path)
      end
    end
  end
  # List the buckets available
  def list_buckets
    @resource.buckets.map { |x| x.name }
  end

  # Returns true if a particular bucket exists.
  def bucket_exists?(name)
    begin
      testVar = @resource.client.list_objects(bucket: name, delimiter: "/")
      return true 
    rescue 
      return false
    end
  end

  # Returns true if object specified exists in the bucket
  def object_exists?(object_name)
    clean_object_name = clean_starting_folder_path(object_name).to_s
    @resource.bucket(@bucket_name).objects({prefix: clean_object_name}).limit(1).any?
  end
end                             
