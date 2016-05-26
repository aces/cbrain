class AddAmazonEc2SecretAccessKeyToRemoteResource < ActiveRecord::Migration
  def change
    add_column :remote_resources, :amazon_ec2_secret_access_key, :string
  end
end
