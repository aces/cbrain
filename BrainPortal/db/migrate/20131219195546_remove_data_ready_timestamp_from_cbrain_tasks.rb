class RemoveDataReadyTimestampFromCbrainTasks < ActiveRecord::Migration
  def up
    remove_column :cbrain_tasks, :data_ready_timestamp
  end

  def down
    add_column :cbrain_tasks, :data_ready_timestamp, :integer
  end
end
