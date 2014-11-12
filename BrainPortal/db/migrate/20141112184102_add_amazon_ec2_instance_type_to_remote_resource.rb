class AddAmazonEc2InstanceTypeToRemoteResource < ActiveRecord::Migration
  def change
    add_column :remote_resources, :amazon_ec2_instance_type, :string
  end
end
