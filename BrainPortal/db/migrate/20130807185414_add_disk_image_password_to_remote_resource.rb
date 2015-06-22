class AddDiskImagePasswordToRemoteResource < ActiveRecord::Migration
  def change
    add_column :remote_resources, :disk_image_password, :string
  end
end
