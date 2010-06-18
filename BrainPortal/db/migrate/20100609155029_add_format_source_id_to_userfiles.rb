class AddFormatSourceIdToUserfiles < ActiveRecord::Migration
  def self.up
    add_column :userfiles, :format_source_id, :integer
  end

  def self.down
    remove_column :userfiles, :format_source_id
  end
end
