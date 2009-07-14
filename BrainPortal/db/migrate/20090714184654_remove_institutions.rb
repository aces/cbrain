class RemoveInstitutions < ActiveRecord::Migration
  def self.up
    drop_table :institutions
  end

  def self.down
    create_table :institutions do |t|
      t.string :name
      t.string :city
      t.string :province
      t.string :country

      t.timestamps
    end
  end
end
