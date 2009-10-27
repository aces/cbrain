class AddCriticalAndDisplayToMessages < ActiveRecord::Migration
  def self.up
    add_column :messages, :critical, :boolean
    add_column :messages, :display, :boolean
  end

  def self.down
    remove_column :messages, :display
    remove_column :messages, :critical
  end
end
