class AddGroupIdToCbrainTasks < ActiveRecord::Migration
  def self.up
    add_column :cbrain_tasks, :group_id, :integer
  end

  def self.down
    remove_column :cbrain_tasks, :group_id
  end
end
