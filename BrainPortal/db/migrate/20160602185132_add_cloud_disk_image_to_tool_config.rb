class AddCloudDiskImageToToolConfig < ActiveRecord::Migration
  def change
    add_column :tool_configs, :cloud_disk_image, :string
  end
end
