class RemoveOnCpuTimestampToCbrainTasks < ActiveRecord::Migration
  def up
    remove_column :cbrain_tasks, :on_cpu_timestamp
  end

  def down
    add_column :cbrain_tasks, :on_cpu_timestamp, :int
  end
end
