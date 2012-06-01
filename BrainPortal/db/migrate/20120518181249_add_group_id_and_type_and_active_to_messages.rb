class AddGroupIdAndTypeAndActiveToMessages < ActiveRecord::Migration
  def self.up
    add_column :messages, :group_id, :integer
    add_column :messages, :type, :string
    add_column :messages, :active, :boolean
  end

  def self.down
    remove_column :messages, :type
    remove_column :messages, :group_id
    remove_column :message,  :active
  end
end
