class RenameTimeoutToRrTimeout < ActiveRecord::Migration
  def self.up
    rename_column :remote_resources, :timeout, :rr_timeout
  end

  def self.down
    rename_column :remote_resources, :rr_timeout, :timeout
  end
end
