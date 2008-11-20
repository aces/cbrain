class CreateUserfiles < ActiveRecord::Migration
  def self.up
    create_table :userfiles do |t|
      t.string :name
      t.integer :size
      t.integer :user_id
      t.integer :parent_id
      t.integer :lft
      t.integer :rgt

      t.timestamps
    end
  end

  def self.down
    drop_table :userfiles
  end
end
