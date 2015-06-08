class RemoveFormatSourceIdFromUserfiles < ActiveRecord::Migration
  def up
    remove_column :userfiles, :format_source_id  
  end

  def down
    add_column :userfiles, :format_source_id, :integer
  end
end
