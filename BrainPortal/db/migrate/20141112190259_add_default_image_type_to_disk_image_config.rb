class AddDefaultImageTypeToDiskImageConfig < ActiveRecord::Migration
  def change
    add_column :disk_image_configs, :default_image_type, :string
  end
end
