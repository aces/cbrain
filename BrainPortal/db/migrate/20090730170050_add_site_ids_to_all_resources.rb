class AddSiteIdsToAllResources < ActiveRecord::Migration
  def self.up
    add_column :users,            :site_id, :integer
    add_column :groups,           :site_id, :integer
  end

  def self.down
    remove_column :users,            :site_id
    remove_column :groups,           :site_id
  end
end
