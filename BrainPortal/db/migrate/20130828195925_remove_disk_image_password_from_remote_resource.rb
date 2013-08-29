class RemoveDiskImagePasswordFromRemoteResource < ActiveRecord::Migration
  def up
    remove_column :remote_resources, :disk_image_password
  end

  def down
    add_column :remote_resources, :disk_image_password, :string
  end
end
