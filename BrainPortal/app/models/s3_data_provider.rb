class S3DataProvider < DataProvider 
  #validates_presence_of :access_key_id, :secret_access_key

  after_initialize :init_connection

  def init_connection
    @s3_connection = S3Connection.new()
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
    @s3_connection.create_bucket(bucket_name)
  end
  
  def impl_is_alive?
    @s3_connection.connected?
  end

  def is_browsable?
    true
  end

  def impl_sync_to_cache(userfile)
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
    @s3_connection.s3object.delete(s3_filename(userfile), bucket_name)
  end
  
  def impl_provider_rename(userfile,newname)
    @s3_connection.s3object.rename s3_filename(userfile), s3_filename(userfile,newname), bucket_name
  end

 def impl_provider_list_all(user)
   s3_connection.bucket.find(bucket_name).objects.map { |object| 
     file = DataProvider::FileInfo.new()
     filename = filename_from_s3_filename(object.key)[1]
     file.name = filename
     file.symbolic_type = :regular
     file.mtime = Time.parse(object.about()["date"]).to_i
     file.size = 0
     file
   }
 end

end



  
