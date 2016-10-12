class RenameDemandsTableToSignups < ActiveRecord::Migration
  def up
    rename_table :demands, :signups
  end

  def down
    rename_table :signups, :demands
  end
end
