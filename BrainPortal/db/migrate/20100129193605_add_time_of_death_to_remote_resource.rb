class AddTimeOfDeathToRemoteResource < ActiveRecord::Migration
  def self.up
    add_column :remote_resources, :time_of_death, :datetime
  end

  def self.down
    remove_column :remote_resources, :time_of_death
  end
end
