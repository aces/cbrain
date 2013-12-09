class AddThreadIdToVmFactory < ActiveRecord::Migration
  def change
    add_column :vm_factories, :thread_id, :int
  end
end
