class AddGroupWritableToUserfiles < ActiveRecord::Migration
  def self.up
    add_column :userfiles, :group_writable, :boolean, :default => false
  end

  def self.down
    remove_column :userfiles, :group_writable
  end
end
