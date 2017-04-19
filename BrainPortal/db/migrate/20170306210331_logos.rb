class Logos < ActiveRecord::Migration
  def up
    add_column :remote_resources, :small_logo, :string
    add_column :remote_resources, :large_logo, :string
  end

  def down
    remove_column :remote_resources, :small_logo
    remove_column :remote_resources, :large_logo
  end
end
