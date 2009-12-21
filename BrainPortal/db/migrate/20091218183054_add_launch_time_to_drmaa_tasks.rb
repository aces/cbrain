class AddLaunchTimeToDrmaaTasks < ActiveRecord::Migration
  def self.up
    add_column :drmaa_tasks, :launch_time, :datetime
  end

  def self.down
    remove_column :drmaa_tasks, :launch_time
  end
end
