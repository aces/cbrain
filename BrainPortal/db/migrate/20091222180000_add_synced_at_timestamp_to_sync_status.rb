class AddSyncedAtTimestampToSyncStatus < ActiveRecord::Migration
  def self.up
    add_column     :sync_status,  :synced_at,  :datetime
  end

  def self.down
    remove_column  :sync_status,  :synced_at
  end
end
