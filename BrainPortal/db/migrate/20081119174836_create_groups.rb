class CreateGroups < ActiveRecord::Migration
  def self.up
    create_table :groups do |t|
      t.string :name
      t.integer :institution_id
      t.integer :manager_id
      t.string :street
      t.string :building
      t.string :room
      t.string :phone
      t.string :fax

      t.timestamps
    end
  end

  def self.down
    drop_table :groups
  end
end
