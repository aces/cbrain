class AddLevelToUserfiles < ActiveRecord::Migration
  def self.up
    add_column :userfiles, :level, :integer
  end

  def self.down
    remove_column :userfiles, :level
  end
end
