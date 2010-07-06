class AddNotSyncableToDataProviders < ActiveRecord::Migration
  def self.up
    add_column    :data_providers, :not_syncable, :boolean, :default => false
  end

  def self.down
    remove_column :data_providers, :not_syncable
  end
end
