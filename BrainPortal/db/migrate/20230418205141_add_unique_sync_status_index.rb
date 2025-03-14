class AddUniqueSyncStatusIndex < ActiveRecord::Migration[5.0]
  def up
    remove_index :sync_status, [ :userfile_id, :remote_resource_id ]
    add_index    :sync_status, [ :userfile_id, :remote_resource_id ], :unique => true
  end

  def down
    remove_index :sync_status, [ :userfile_id, :remote_resource_id ]
  end
end
