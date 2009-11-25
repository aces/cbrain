class AddUserIdAndActiveToSessions < ActiveRecord::Migration
  def self.up
    add_column :sessions, :user_id, :integer
    add_column :sessions, :active, :boolean
  end

  def self.down
    remove_column :sessions, :active
    remove_column :sessions, :user_id
  end
end
