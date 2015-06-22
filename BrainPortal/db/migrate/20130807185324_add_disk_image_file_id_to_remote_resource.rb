class AddDiskImageFileIdToRemoteResource < ActiveRecord::Migration
  def change
    add_column :remote_resources, :disk_image_file_id, :int
  end
end
