class AddIndexToTasks < ActiveRecord::Migration
  def self.up
    add_index    :cbrain_tasks, :type
    add_index    :cbrain_tasks, :user_id
    add_index    :cbrain_tasks, :bourreau_id
    add_index    :cbrain_tasks, :status
    add_index    :cbrain_tasks, :launch_time
  end

  def self.down
    remove_index :cbrain_tasks, :type
    remove_index :cbrain_tasks, :user_id
    remove_index :cbrain_tasks, :bourreau_id
    remove_index :cbrain_tasks, :status
    remove_index :cbrain_tasks, :launch_time
  end
end
