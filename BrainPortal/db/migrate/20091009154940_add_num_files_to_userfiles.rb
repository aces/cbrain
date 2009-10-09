class AddNumFilesToUserfiles < ActiveRecord::Migration
  def self.up
    add_column :userfiles, :num_files, :integer
  end

  def self.down
    remove_column :userfiles, :num_files
  end
end
