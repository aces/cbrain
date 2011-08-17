class AddCreatorIdToGroup < ActiveRecord::Migration
  def self.up
    add_column :groups, :creator_id, :integer
  end

  def self.down
    remove_column :groups, :creator_id
  end
end
