class AddPassword < ActiveRecord::Migration
  def self.up
    add_column :users, :crypt_password, :string
  end

  def self.down
    remove_column :users, :crypt_password
  end
end
