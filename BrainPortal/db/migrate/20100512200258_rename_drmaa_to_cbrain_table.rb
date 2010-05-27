
class RenameDrmaaToCbrainTable < ActiveRecord::Migration

  def self.up
    rename_table :drmaa_tasks, :cbrain_tasks
  end

  def self.down
    rename_table :cbrain_tasks, :drmaa_tasks
  end

end
