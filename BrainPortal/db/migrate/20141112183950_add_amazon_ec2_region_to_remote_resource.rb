class AddAmazonEc2RegionToRemoteResource < ActiveRecord::Migration
  def change
    add_column :remote_resources, :amazon_ec2_region, :string
  end
end
