class CreateStatistics < ActiveRecord::Migration
  def self.up
    create_table :statistics do |t|
      t.integer :bourreau_id
      t.integer :user_id
      t.string :task_name
      t.integer :count
      t.timestamps
    end
  end

  def self.down
    drop_table :statistics
  end
end
