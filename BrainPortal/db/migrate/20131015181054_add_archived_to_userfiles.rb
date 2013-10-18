class AddArchivedToUserfiles < ActiveRecord::Migration
  def change
    add_column :userfiles, :archived, :boolean, :default => false
  end
end
