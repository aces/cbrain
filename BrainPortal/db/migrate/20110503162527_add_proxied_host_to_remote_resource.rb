class AddProxiedHostToRemoteResource < ActiveRecord::Migration
  def self.up
    add_column    :remote_resources, :proxied_host, :string
  end

  def self.down
    remove_column :remote_resources, :proxied_host
  end
end
