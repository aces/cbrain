class AddTaskToUserfiles < ActiveRecord::Migration
  def self.up
    add_column :userfiles, :task, :string
  end

  def self.down
    remove_column :userfiles, :task
  end
end
