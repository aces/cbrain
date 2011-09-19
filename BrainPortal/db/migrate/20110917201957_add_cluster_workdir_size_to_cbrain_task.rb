class AddClusterWorkdirSizeToCbrainTask < ActiveRecord::Migration
  def self.up
    add_column :cbrain_tasks, :cluster_workdir_size, :decimal, :precision => 24, :scale => 0
  end

  def self.down
    remove_column :cbrain_tasks, :cluster_workdir_size
  end
end
