require 'aws/s3'

class S3Connection
  include AWS::S3
  def initialize(access_key, secret_key)
    @base     = Base
    @service  = Service
    @bucket   = Bucket
    @s3object = S3Object
    
    @base.establish_connection!(
      :access_key_id     => (access_key || "blah"),
      :secret_access_key => (secret_key || "blah")
    )
  end
  
  attr_accessor :base,:service, :bucket, :s3object

  def execute_on_s3
     yield self                                 
  end
  
  def create_bucket(bucket_name)
    @bucket.create(bucket_name)
  end

  def connected?
    @base.connected?
  end

  def list_buckets
   @service.buckets
  end
  
  def bucket_exists?(name)
    list_buckets.each do |bucket|
      if bucket.name == name 
        return true
      end
     end
     false
  end
end
