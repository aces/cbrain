class AddOpenStackDiskImageIdFromDiskImageConfigs < ActiveRecord::Migration
  def change
    add_column :disk_image_configs, :open_stack_disk_image_id, :string
  end
end
