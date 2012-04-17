class RawUser < ActiveRecord::Base
   self.table_name = "users"
end

class MigrateRolesToTypes < ActiveRecord::Migration
  def self.up
    add_column :users, :type, :string, :after => :email
    add_index  :users, :type
    
    RawUser.reset_column_information
    
    RawUser.all.each do |u|
      if u.role == "user"
        u.type = "NormalUser"
      elsif u.role == "site_manager"
        u.type = "SiteManager"
      elsif u.role == "admin"
        u.type = "AdminUser"
      end
      u.save!
    end
    
    remove_column :users, :role
  end

  def self.down
    add_column :users, :role, :string, :after => :email
    add_index  :users, :role
    
    rename_column :users, :type, :old_type
    
    RawUser.reset_column_information
        
    RawUser.all.each do |u|
      if u.old_type == "NormalUser"
        u.role = "user"
      elsif u.old_type == "SiteManager"
        u.role = "site_manager"
      elsif u.old_type == "AdminUser"
        u.role = "admin"
      end
      u.save!
    end
    
    remove_column :users, :old_type
  end
end
