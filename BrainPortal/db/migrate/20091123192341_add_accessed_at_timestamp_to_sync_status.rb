class AddAccessedAtTimestampToSyncStatus < ActiveRecord::Migration
  def self.up
    add_column     :sync_status,  :accessed_at,  :datetime
  end

  def self.down
    remove_column  :sync_status,  :accessed_at
  end
end
