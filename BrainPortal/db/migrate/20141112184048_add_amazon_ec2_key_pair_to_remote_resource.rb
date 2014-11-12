class AddAmazonEc2KeyPairToRemoteResource < ActiveRecord::Migration
  def change
    add_column :remote_resources, :amazon_ec2_key_pair, :string
  end
end
