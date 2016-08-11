class CreateTaskVmAllocations < ActiveRecord::Migration
  def change
    create_table :task_vm_allocations do |t|
      t.integer :vm_id
      t.integer :task_id

      t.timestamps
    end
  end
end
