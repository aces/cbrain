class AddCacheMd5ToRemoteResource < ActiveRecord::Migration
  def self.up
    add_column    :remote_resources, :cache_md5, :string
  end

  def self.down
    remove_column :remote_resources, :cache_md5
  end
end
