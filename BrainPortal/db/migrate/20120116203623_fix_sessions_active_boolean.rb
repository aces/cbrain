class FixSessionsActiveBoolean < ActiveRecord::Migration
  def self.up
    change_column :sessions,         :active,           :boolean, :default => nil,   :null => true
  end

  def self.down
    change_column :sessions,         :active,           :boolean, :default => false, :null => false
  end
end
