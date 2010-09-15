class AddToolConfigModel < ActiveRecord::Migration
  def self.up
    create_table :tool_configs do |t|
      t.text    :description
      t.integer :tool_id
      t.integer :bourreau_id    # can be NIL when it applies to all bourreaux!
      t.text    :env_hash
      t.text    :script_prologue
      t.timestamps
    end
  end

  def self.down
    drop_table :tool_configs
  end
end
