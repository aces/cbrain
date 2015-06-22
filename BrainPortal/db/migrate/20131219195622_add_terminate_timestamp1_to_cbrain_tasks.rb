class AddTerminateTimestamp1ToCbrainTasks < ActiveRecord::Migration
  def change
    add_column :cbrain_tasks, :terminate_timestamp, :datetime
  end
end
