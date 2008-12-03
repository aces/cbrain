class AddUserIdToTasks < ActiveRecord::Migration
  def self.up
    add_column :drmaa_tasks, :user_id, :integer 
  end

  def self.down
    remove_column :drmaa_tasks, :user_id
  end
end
