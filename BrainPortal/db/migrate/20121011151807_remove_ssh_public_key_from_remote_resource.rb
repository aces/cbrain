class RemoveSshPublicKeyFromRemoteResource < ActiveRecord::Migration
  def self.up
    remove_column :remote_resources, :ssh_public_key
  end

  def self.down
    add_column :remote_resources, :ssh_public_key, :text
  end
end
