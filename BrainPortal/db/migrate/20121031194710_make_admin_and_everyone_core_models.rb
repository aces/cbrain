class MakeAdminAndEveryoneCoreModels < ActiveRecord::Migration
  def self.up
    User.admin.update_attribute(:type, "CoreAdmin")
    Group.everyone.update_attribute(:type, "EveryoneGroup")
  end

  def self.down
    User.admin.update_attribute(:type, "AdminUser")
    Group.everyone.update_attribute(:type, "SystemGroup")
  end
end
