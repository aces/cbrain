class AddPortalLockedToRemoteResources < ActiveRecord::Migration
  def self.up
    add_column :remote_resources, :portal_locked, :boolean
  end

  def self.down
    remove_column :remote_resources, :portal_locked
  end
end
