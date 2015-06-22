class RemoveTerminateTimestampFromCbrainTasks < ActiveRecord::Migration
  def up
    remove_column :cbrain_tasks, :terminate_timestamp
  end

  def down
    add_column :cbrain_tasks, :terminate_timestamp, :integer
  end
end
