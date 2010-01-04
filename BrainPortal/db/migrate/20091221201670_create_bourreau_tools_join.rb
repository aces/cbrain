class CreateBourreauToolsJoin < ActiveRecord::Migration
  def self.up
    create_table :bourreaux_tools, :id => false do |t|
      t.integer :tool_id 
      t.integer :bourreau_id
    end
  end

  def self.down
    drop_table :bourreaux_tools
  end
end
