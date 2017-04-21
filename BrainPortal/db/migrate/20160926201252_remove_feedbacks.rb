class RemoveFeedbacks < ActiveRecord::Migration
  def self.up
    drop_table :feedbacks
  end

  def self.down
    add_table :feedbacks do |t|
      t.string :summary
      t.text :details
      t.integer :user_id

      t.timestamps
    end

  end
end
