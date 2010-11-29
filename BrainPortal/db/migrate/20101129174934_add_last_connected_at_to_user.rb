class AddLastConnectedAtToUser < ActiveRecord::Migration
  def self.up
    add_column    :users, :last_connected_at, :datetime
  end

  def self.down
    remove_column :users, :last_connected_at
  end
end
