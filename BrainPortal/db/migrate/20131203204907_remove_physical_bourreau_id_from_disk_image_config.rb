class RemovePhysicalBourreauIdFromDiskImageConfig < ActiveRecord::Migration
  def up
    remove_column :disk_image_configs, :physical_bourreau_id
  end

  def down
    add_column :disk_image_configs, :physical_bourreau_id, :integer
  end
end
