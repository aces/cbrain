class AddHiddenToUserfiles < ActiveRecord::Migration
  def self.up
    add_column    :userfiles, :hidden, :boolean, :default => false
    add_index     :userfiles, :hidden
  end

  def self.down
    remove_column :userfiles, :hidden
  end
end
