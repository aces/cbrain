class ChangeUserfileSizeToDecimal < ActiveRecord::Migration
  def self.up
    change_column :userfiles, :size, :decimal, :precision  => 24, :scale  => 0
  end

  def self.down
    change_column :userfiles, :size, :integer
  end
end
