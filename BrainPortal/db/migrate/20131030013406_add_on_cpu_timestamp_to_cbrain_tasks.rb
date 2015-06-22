class AddOnCpuTimestampToCbrainTasks < ActiveRecord::Migration
  def change
    add_column :cbrain_tasks, :on_cpu_timestamp, :int
  end
end
