class AddPasswordResetToUsers < ActiveRecord::Migration
  def self.up
    add_column :users, :password_reset, :boolean
  end

  def self.down
    remove_column :users, :password_reset
  end
end
