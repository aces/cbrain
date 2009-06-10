class CreateGroupEveryone < ActiveRecord::Migration

  def self.up
    everyone = Group.new
    everyone.name = "everyone"
    everyone.save!
  end

  def self.down
    everyone = Group.find_by_name("everyone")
    everyone.destroy
  end

end
