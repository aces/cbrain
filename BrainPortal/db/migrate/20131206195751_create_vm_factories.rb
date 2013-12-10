class CreateVmFactories < ActiveRecord::Migration
  def change
    create_table :vm_factories do |t|
      t.integer :disk_image_file_id
      t.integer :tau
      t.float :mu_plus
      t.float :mu_minus
      t.integer :nu_plus
      t.integer :nu_minus
      t.integer :k_plus
      t.integer :k_minus
      t.datetime :timestamp_of_last_iteration

      t.timestamps
    end
  end
end
