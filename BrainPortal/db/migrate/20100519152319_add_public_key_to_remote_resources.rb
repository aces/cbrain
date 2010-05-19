class AddPublicKeyToRemoteResources < ActiveRecord::Migration
  def self.up
    add_column :remote_resources, :ssh_public_key, :text
  end

  def self.down
    remove_column :remote_resources, :ssh_public_key
  end
end
