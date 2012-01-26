
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

