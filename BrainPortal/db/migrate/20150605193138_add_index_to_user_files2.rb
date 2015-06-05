class AddIndexToUserFiles2 < ActiveRecord::Migration
  def change
    add_index :userfiles, [:hidden, :id]
    add_index :userfiles, [:format_source_id, :id]
  end
end
