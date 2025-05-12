class DropTaskVmAllocations < ActiveRecord::Migration[5.0]
  def up
    TaskVmAllocation.destroy_all if defined?(TaskVmAllocation)
  end
end
