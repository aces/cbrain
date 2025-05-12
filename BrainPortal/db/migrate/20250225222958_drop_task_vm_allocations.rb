class DropTaskVmAllocations < ActiveRecord::Migration[5.0]
  def change
    drop_table :task_vm_allocations
  end
end
