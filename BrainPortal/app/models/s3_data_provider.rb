
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

class S3DataProvider < DataProvider 

  validates_presence_of :cloud_storage_client_identifier, :cloud_storage_client_token

  def init_connection
    @s3_connection = S3Connection.new(self.cloud_storage_client_identifier, self.cloud_storage_client_token)
  end

  def bucket_name 
    "gbrain_#{self.name}"
  end
  
  attr_accessor :s3_connection
  
  def s3_filename(userfile,newname=nil)
    namekey = newname || userfile.name
    "#{userfile.id}_#{namekey}"
  end
  

  def provider_full_path(userfile)
    "#{bucket_name}/#{s3_filename(userfile)}"
  end

  def filename_from_s3_filename(s3_filename)
    userfile_id,filename=s3_filename.split('_', 2)
  end

  def create_base_bucket
    init_connection
    @s3_connection.create_bucket(bucket_name)
  end
  
  def impl_is_alive?
    init_connection
    @s3_connection.connected?
  rescue
    false
  end

  def is_browsable?
    false
  end

  def impl_sync_to_cache(userfile)
    init_connection
    local_full = cache_full_pathname(userfile)

    mkdir_cache_subdirs(userfile)
    if userfile.is_a?(FileCollection)
      cb_error "S3 data provider does not yet support file collection"
    end
    open(local_full, 'w') do |file|
      @s3_connection.s3object.stream(s3_filename(userfile), bucket_name) do |chunk|
        file.write chunk
      end
    end
  end

  def impl_sync_to_provider(userfile)
    init_connection
    create_base_bucket unless @s3_connection.bucket_exists?(bucket_name)
    local_full = cache_full_pathname(userfile)                                                                                                                  
    mkdir_cache_subdirs(userfile)                                                                                     
    if userfile.is_a?(FileCollection)                                                                                 
      cb_error "S3 data provider does not yet support file collection"                                                
    end                                                                                                                    
    bucket = @s3_connection.bucket.find(bucket_name)                                                               
    @s3_connection.s3object.store(s3_filename(userfile), open(local_full), bucket_name)
  end

  def impl_provider_erase(userfile)
    init_connection
    @s3_connection.s3object.delete(s3_filename(userfile), bucket_name)
  end
  
  def impl_provider_rename(userfile,newname)
    init_connection
    @s3_connection.s3object.rename s3_filename(userfile), s3_filename(userfile,newname), bucket_name
  end

  def impl_provider_list_all(user)
    raise "Disabled"
  #  init_connection
  #  s3_connection.bucket.find(bucket_name).objects.map do |object| 
  #    file = DataProvider::FileInfo.new()
  #    filename = filename_from_s3_filename(object.key)[1]
  #    file.name = filename
  #    file.symbolic_type = :regular
  #    file.mtime = Time.parse(object.about()["date"]).to_i
  #    file.size = 0
  #    file
  #  end
 end

end
