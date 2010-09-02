class ChangeTimeOfDeathForDataProviderToDatetime < ActiveRecord::Migration
  def self.up
    change_column :data_providers, :time_of_death, :datetime
  end

  def self.down
    change_column :data_providers, :time_of_death, :date
  end
end
