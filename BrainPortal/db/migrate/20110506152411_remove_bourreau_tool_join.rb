class RemoveBourreauToolJoin < ActiveRecord::Migration
  def self.up
    remove_index    :bourreaux_tools, :bourreau_id
    remove_index    :bourreaux_tools, :tool_id
    drop_table      :bourreaux_tools
  end

  def self.down
    create_table :bourreaux_tools, :id => false do |t|
      t.integer  :tool_id 
      t.integer  :bourreau_id
    end
    add_index    :bourreaux_tools, :bourreau_id
    add_index    :bourreaux_tools, :tool_id
  end
end
