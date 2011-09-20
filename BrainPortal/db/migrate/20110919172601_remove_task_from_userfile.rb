class RemoveTaskFromUserfile < ActiveRecord::Migration
  def self.up
    remove_column :userfiles, :task
  end

  def self.down
    add_column :userfiles, :task, :string
  end
end
