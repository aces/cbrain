class RawUser < ActiveRecord::Base
   self.table_name = "users"
end

class MigrateRolesToTypes < ActiveRecord::Migration
  def self.up
    add_column :users, :type, :string
    
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
    add_column :users, :role, :string
    
    RawUser.all.each do |u|
      if u.type == "NormalUser"
        u.role = "user"
      elsif u.type == "SiteManager"
        u.role = "site_manager"
      elsif u.type == "AdminUser"
        u.role = "admin"
      end
      u.save!
    end
    
    remove_column :users, :type
  end
end
