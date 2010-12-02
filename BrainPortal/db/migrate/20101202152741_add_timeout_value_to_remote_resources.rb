class AddTimeoutValueToRemoteResources < ActiveRecord::Migration
  def self.up
    add_column :remote_resources, :timeout, :integer
  end

  def self.down
    remove_column :remote_resources, :timeout
  end
end
