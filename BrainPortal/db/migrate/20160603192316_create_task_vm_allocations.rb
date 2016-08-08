class CreateTaskVmAllocations < ActiveRecord::Migration
  def change
    create_table :task_vm_allocations do |t|
      t.string :vm_id
      t.string :task_id

      t.timestamps
    end
  end
end
