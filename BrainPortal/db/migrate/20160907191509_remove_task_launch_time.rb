class RemoveTaskLaunchTime < ActiveRecord::Migration
  def self.up
    change_table :cbrain_tasks do |t|
      t.remove :launch_time
    end
  end

  def self.down
    change_table :cbrain_tasks do |t|
      t.add :launch_time
    end
  end
end
