class AddTypeToGroups < ActiveRecord::Migration
  def self.up
    add_column :groups, :type, :string
  end

  def self.down
    remove_column :groups, :type
  end
end
