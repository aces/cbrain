class AddAmazonEc2AccessKeyIdToRemoteResource < ActiveRecord::Migration
  def change
    add_column :remote_resources, :amazon_ec2_access_key_id, :string
  end
end
