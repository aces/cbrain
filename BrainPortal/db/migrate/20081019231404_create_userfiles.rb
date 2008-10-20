class CreateUserfiles < ActiveRecord::Migration
  def self.up
    create_table :userfiles do |t|
      t.column      :owner_id,   :integer
      t.column      :base_name,  :string
      t.column      :file_size,  :integer
      t.timestamps
    end
  end

  def self.down
    drop_table :userfiles
  end
end
