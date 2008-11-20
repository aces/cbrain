class CreateInstitutions < ActiveRecord::Migration
  def self.up
    create_table :institutions do |t|
      t.string :name
      t.string :city
      t.string :province
      t.string :country

      t.timestamps
    end
  end

  def self.down
    drop_table :institutions
  end
end
