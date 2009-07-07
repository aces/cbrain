class AddUserIdToCustomFilter < ActiveRecord::Migration
  def self.up
    add_column :custom_filters, :user_id, :integer
  end

  def self.down
    remove_column :custom_filters, :user_id
  end
end
