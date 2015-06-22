class AddPidToVmFactory < ActiveRecord::Migration
  def change
    add_column :vm_factories, :pid, :int
  end
end
