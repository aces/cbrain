class AddImmutableToUserfiles < ActiveRecord::Migration
  def change
    add_column :userfiles, :immutable, :boolean, :default => false
  end
end
