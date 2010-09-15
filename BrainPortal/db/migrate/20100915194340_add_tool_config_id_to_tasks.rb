class AddToolConfigIdToTasks < ActiveRecord::Migration
  def self.up
    add_column    :cbrain_tasks, :tool_config_id, :integer
  end

  def self.down
    remove_column :cbrain_tasks, :tool_config_id
  end
end
