class AddLockedToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :account_locked, :boolean
  end

  def self.down
    remove_column :users, :account_locked
  end
end
