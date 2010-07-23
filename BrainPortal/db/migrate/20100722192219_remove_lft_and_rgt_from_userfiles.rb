class RemoveLftAndRgtFromUserfiles < ActiveRecord::Migration
  def self.up
    remove_column :userfiles, :lft
    remove_column :userfiles, :rgt
  end

  def self.down
    add_column :userfiles, :lft, :integer
    add_column :userfiles, :rgt, :integer
  end
end
