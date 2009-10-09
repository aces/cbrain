class CreateMessages < ActiveRecord::Migration
  def self.up
    create_table :messages do |t|
      t.string    :header
      t.text      :description
      t.text      :variable_text
      t.string    :message_type
      t.boolean   :read
      t.integer   :user_id
      t.datetime  :expiry

      t.timestamps
    end
  end

  def self.down
    drop_table :messages
  end
end
