class AddSyncStatusTable < ActiveRecord::Migration
  def self.up
    create_table :sync_status do |t|

      t.integer    :userfile_id
      t.integer    :remote_resource_id
      t.string     :status         # InSync, ToDP, ToCache
      t.timestamps

    end
    add_index    :sync_status, :userfile_id
    add_index    :sync_status, :remote_resource_id
    add_index    :sync_status, [ :userfile_id, :remote_resource_id ]
  end

  def self.down
    remove_index :sync_status, :userfile_id
    remove_index :sync_status, :remote_resource_id
    remove_index :sync_status, [ :userfile_id, :remote_resource_id ]
    drop_table   :sync_status
  end
end
