class CreateTools < ActiveRecord::Migration
  def self.up
    create_table :tools do |t|
      t.string :tool_name  
      t.integer :user_id
      t.integer :group_id
      t.string :category
      t.timestamps
    end
  end

  def self.down
    drop_table :tools
  end
end
