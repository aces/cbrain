class AddDataReadyTimestamp1ToCbrainTasks < ActiveRecord::Migration
  def change
    add_column :cbrain_tasks, :data_ready_timestamp, :datetime
  end
end
