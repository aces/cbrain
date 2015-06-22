class AddTerminateTimestampToCbrainTasks < ActiveRecord::Migration
  def change
    add_column :cbrain_tasks, :terminate_timestamp, :integer
  end
end
