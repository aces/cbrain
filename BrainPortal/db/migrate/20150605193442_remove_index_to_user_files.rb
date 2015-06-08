class RemoveIndexToUserFiles < ActiveRecord::Migration
  def change
    remove_index :userfiles, [:archived]
    remove_index :userfiles, [:hidden]
    remove_index :userfiles, [:immutable]
    remove_index :userfiles, [:format_source_id]
  end
end
