class AddDiskImageUserToRemoteResource < ActiveRecord::Migration
  def change
    add_column :remote_resources, :disk_image_user, :string
  end
end
