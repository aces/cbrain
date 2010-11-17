class AddGroupIdToToolConfig < ActiveRecord::Migration
  def self.up
    add_column    :tool_configs, :group_id, :integer
  end

  def self.down
    remove_column :tool_configs, :group_id
  end
end
