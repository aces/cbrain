class RemoveTaskLaunchTime < ActiveRecord::Migration
  def self.up
    remove_column :cbrain_tasks, :launch_time
  end

  def self.down
    add_column :cbrain_tasks, :launch_time, :datetime
  end
end
