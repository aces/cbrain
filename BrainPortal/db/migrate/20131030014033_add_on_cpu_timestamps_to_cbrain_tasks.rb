class AddOnCpuTimestampsToCbrainTasks < ActiveRecord::Migration
  def change
    add_column :cbrain_tasks, :on_cpu_timestamp, :datetime
  end
end
