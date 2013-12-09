class AddNameToVmFactory < ActiveRecord::Migration
  def change
    add_column :vm_factories, :name, :string
  end
end
