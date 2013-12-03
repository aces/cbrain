class RemoveOpenStackDiskImageIdFromDiskImageConfigs < ActiveRecord::Migration
  def up
    remove_column :disk_image_configs, :open_stack_disk_image_id
  end

  def down
    add_column :disk_image_configs, :open_stack_disk_image_id, :integer
  end
end
