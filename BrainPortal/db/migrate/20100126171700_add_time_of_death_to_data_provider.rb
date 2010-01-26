class AddTimeOfDeathToDataProvider < ActiveRecord::Migration
  def self.up
    add_column :data_providers, :time_of_death, :date
  end

  def self.down
    remove_column :data_providers, :time_of_death
  end
end
