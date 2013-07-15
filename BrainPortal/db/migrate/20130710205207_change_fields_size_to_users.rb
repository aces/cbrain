class ChangeFieldsSizeToUsers < ActiveRecord::Migration
  def up
    change_column :users, :crypted_password, :string, :limit => nil
    change_column :users, :salt, :string, :limit => nil
  end

  def down
    change_column :users, :crypted_password, :string, :limit => 40
    change_column :users, :salt, :string, :limit => 40
  end
end
