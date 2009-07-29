class AddTypeToUserfiles < ActiveRecord::Migration
  def self.up
    add_column :userfiles, :type, :string
  end

  def self.down
    remove_column :userfiles, :type
  end
end
