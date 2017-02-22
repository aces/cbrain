class SignupsTweaks < ActiveRecord::Migration
  def up
    change_column :signups, :admin_comment, :text
    change_column :signups, :comment, :text
    add_column    :signups, :user_id, :integer
    add_column    :signups, :hidden, :boolean, :default => false

  end

  def down
    remove_column :signups, :user_id
    remove_column :signups, :hidden
  end
end
