class AddBourreauIdFromDiskImageConfig < ActiveRecord::Migration
  def change
    add_column :disk_image_configs, :bourreau_id, :integer
  end
end
