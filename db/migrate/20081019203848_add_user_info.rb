class AddUserInfo < ActiveRecord::Migration
  def self.up
    add_column :users, :full_name, :string
    add_column :users, :groups, :string
  end

  def self.down
    remove_column :users, :groups
    remove_column :users, :full_name
  end
end
