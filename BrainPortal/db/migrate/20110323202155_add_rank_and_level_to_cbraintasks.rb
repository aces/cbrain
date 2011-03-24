class AddRankAndLevelToCbraintasks < ActiveRecord::Migration
  def self.up
    add_column    :cbrain_tasks, :level, :integer
    add_column    :cbrain_tasks, :rank,  :integer
  end

  def self.down
    remove_column :cbrain_tasks, :level
    remove_column :cbrain_tasks, :rank
  end
end
