class RemoveOpenStackDefaultFlavorFromDiskImageConfig < ActiveRecord::Migration
  def up
    remove_column :disk_image_configs, :open_stack_default_flavor
  end

  def down
    add_column :disk_image_configs, :open_stack_default_flavor, :string
  end
end
