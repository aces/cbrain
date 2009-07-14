class AssignSubgroupsToOldGroups < ActiveRecord::Migration
  def self.up
    everyone = Group.find_by_name("everyone")
    everyone.type = "SystemGroup"
    everyone.save!
    
    User.all.each do |user|
      g = Group.find_or_create_by_name(:name => user.login, :user_ids => [user.id])
      g.type = "SystemGroup"
      g.save!
    end
    
    Group.all.each do |group|
      unless group.type
        group.type = "WorkGroup"
        group.save!
      end
    end
  end

  def self.down
    Group.all.each do |group|
      group.type = nil
      group.save!
    end
  end
end
