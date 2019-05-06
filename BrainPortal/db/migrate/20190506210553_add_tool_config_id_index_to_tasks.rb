class AddToolConfigIdIndexToTasks < ActiveRecord::Migration[5.0]
  def change
    add_index :cbrain_tasks, :tool_config_id
  end
end
