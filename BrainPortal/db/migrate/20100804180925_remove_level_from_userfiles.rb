class RemoveLevelFromUserfiles < ActiveRecord::Migration
  def self.up
    remove_column :userfiles, :level
  end

  def self.down
    add_column :userfiles, :level, :integer
  end
end
