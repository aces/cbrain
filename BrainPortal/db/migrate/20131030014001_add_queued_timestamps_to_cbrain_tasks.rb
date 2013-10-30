class AddQueuedTimestampsToCbrainTasks < ActiveRecord::Migration
  def change
    add_column :cbrain_tasks, :queued_timestamp, :datetime
  end
end
