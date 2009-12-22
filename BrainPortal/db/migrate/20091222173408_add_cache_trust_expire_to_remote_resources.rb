class AddCacheTrustExpireToRemoteResources < ActiveRecord::Migration
  def self.up
    add_column    :remote_resources, :cache_trust_expire, :integer, :default => 0
  end

  def self.down
    remove_column :remote_resources, :cache_trust_expire
  end
end
