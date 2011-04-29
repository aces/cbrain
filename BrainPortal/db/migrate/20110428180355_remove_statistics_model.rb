class RemoveStatisticsModel < ActiveRecord::Migration
  def self.up
    drop_table :statistics
  end

  def self.down
    create_table :statistics do |t|
      t.integer :bourreau_id
      t.integer :user_id
      t.string :task_name
      t.integer :count
      t.timestamps
  end
end
