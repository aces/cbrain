class RemoveUserPreferences < ActiveRecord::Migration
  def self.up
    drop_table :user_preferences
  end

  def self.down
    create_table :user_preferences do |t|
      t.integer :user_id
      t.string :bourreau_id
      t.integer :data_provider_id
      t.text :other_options

      t.timestamps
    end
  end
end
