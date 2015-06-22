class RemoveQueuedTimestampToCbrainTasks < ActiveRecord::Migration
  def up
    remove_column :cbrain_tasks, :queued_timestamp
  end

  def down
    add_column :cbrain_tasks, :queued_timestamp, :int
  end
end
