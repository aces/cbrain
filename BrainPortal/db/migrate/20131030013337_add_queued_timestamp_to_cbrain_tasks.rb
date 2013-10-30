class AddQueuedTimestampToCbrainTasks < ActiveRecord::Migration
  def change
    add_column :cbrain_tasks, :queued_timestamp, :int
  end
end
