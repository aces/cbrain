class AddGroupsToUserfiles < ActiveRecord::Migration
  def self.up
    add_column :userfiles, :group_id, :integer
  end

  def self.down
    remove_column :userfiles, :group_id, :integer
  end
end
