class AddDiskImageIdToDiskImageConfig < ActiveRecord::Migration
  def change
    add_column :disk_image_configs, :disk_image_id, :string
  end
end
