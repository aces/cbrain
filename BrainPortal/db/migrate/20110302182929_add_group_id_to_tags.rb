class AddGroupIdToTags < ActiveRecord::Migration
  def self.up
    add_column :tags, :group_id, :integer
  end

  def self.down
    remove_column :tags, :group_id
  end
end
