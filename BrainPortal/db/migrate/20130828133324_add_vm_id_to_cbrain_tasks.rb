class AddVmIdToCbrainTasks < ActiveRecord::Migration
  def change
    add_column :cbrain_tasks, :vm_id, :int
  end
end
