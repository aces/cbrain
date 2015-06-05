class AddIndexToUserFiles < ActiveRecord::Migration
  def change
    add_index :userfiles, [:archived, :id]
    add_index :userfiles, [:immutable, :id]
  end
end
