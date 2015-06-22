class AddOpenStackDefaultFlavorToDiskImageConfig < ActiveRecord::Migration
  def change
    add_column :disk_image_configs, :open_stack_default_flavor, :string
  end
end
