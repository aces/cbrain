class AddLastSentToMessages < ActiveRecord::Migration
  def self.up
    add_column :messages, :last_sent, :datetime
  end

  def self.down
    remove_column :messages, :last_sent
  end
end
