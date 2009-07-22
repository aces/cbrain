class EnsureGroupSetForEveryUserfile < ActiveRecord::Migration
  def self.up
    User.all.each do |u|
      group_id = SystemGroup.find_by_name(u.login).id
      u.userfiles.all.each do |file|
        unless file.group_id
          file.group_id = group_id
          file.save!
        end
      end
    end
  end

  def self.down
  end
end
