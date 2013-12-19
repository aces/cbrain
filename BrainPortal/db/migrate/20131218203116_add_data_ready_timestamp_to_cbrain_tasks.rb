class AddDataReadyTimestampToCbrainTasks < ActiveRecord::Migration
  def change
    add_column :cbrain_tasks, :data_ready_timestamp, :integer
  end
end
