
class RenameTasksColumns < ActiveRecord::Migration

  def self.up
    rename_column :cbrain_tasks, :drmaa_jobid,   :cluster_jobid
    rename_column :cbrain_tasks, :drmaa_workdir, :cluster_workdir
  end

  def self.down
    rename_column :cbrain_tasks, :cluster_workdir, :drmaa_workdir
    rename_column :cbrain_tasks, :cluster_jobid,   :drmaa_jobid
  end

end
