class AddIndexToUserFile < ActiveRecord::Migration
  def change
    add_index :userfiles, [ :format_source_id, :type ]
    add_index :userfiles, [ :format_source_id, :user_id ]
    add_index :userfiles, [ :format_source_id, :data_provider_id ]
    add_index :userfiles, [ :format_source_id, :group_id ]
  end
end
