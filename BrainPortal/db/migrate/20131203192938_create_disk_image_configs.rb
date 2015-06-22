class CreateDiskImageConfigs < ActiveRecord::Migration
  def change
    create_table :disk_image_configs do |t|
      t.integer :disk_image_bourreau_id
      t.integer :physical_bourreau_id
      t.integer :open_stack_disk_image_id

      t.timestamps
    end
  end
end
