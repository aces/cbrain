class AddUserManualUrlToRemoteResources < ActiveRecord::Migration
  def self.up
    add_column    :remote_resources, :help_url, :string
  end

  def self.down
    remove_column :remote_resources, :help_url
  end
end
