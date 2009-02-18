class AddClusterNameToTasks < ActiveRecord::Migration
  def self.up
    add_column :drmaa_tasks, :cluster_name, :string 
  end

  def self.down
    remove_column :drmaa_tasks, :cluster_name
  end
end
