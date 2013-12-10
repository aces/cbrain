class RemoveThreadIdToVmFactory < ActiveRecord::Migration
  def up
    remove_column :vm_factories, :thread_id
  end

  def down
    add_column :vm_factories, :thread_id, :int
  end
end
