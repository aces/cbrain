class CreateSelfGroupForEachUser < ActiveRecord::Migration
  def self.up
    users = User.all
    groups = Group.all
    groupnames = {}
    groups.each { |g| groupnames[g.name] = 1 }

    users.each do |u|
      login = u.login
      next if groupnames.has_key?(login)
      newgroup = SystemGroup.new(:name => login)
      newgroup.save!
      group_ids = u.group_ids
      group_ids << newgroup.id unless group_ids.include?(newgroup.id)
      u.group_ids = group_ids
      u.save!
    end
  end

  def self.down
  end
end
