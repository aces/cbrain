class AddGroupsToInstitutions < ActiveRecord::Migration
  def self.up
    add_column :institutions, :group_id, :integer
  end

  def self.down
    remove_column :institutions, :group_id, :integer
  end
end
