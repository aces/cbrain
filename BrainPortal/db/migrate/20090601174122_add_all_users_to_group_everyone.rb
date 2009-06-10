class AddAllUsersToGroupEveryone < ActiveRecord::Migration
  def self.up
    everyone = Group.find_by_name("everyone")
    everyone_id = everyone.id

    User.all.each do |u|
      groups = u.group_ids
      groups << everyone_id
      u.group_ids = groups
      u.save!
    end

  end

  def self.down
    everyone = Group.find_by_name("everyone")
    everyone_id = everyone.id

    User.all.each do |u|
      groups = u.group_ids
      groups.delete(everone_id)
      u.group_ids = groups
      u.save!
    end
  end

end
