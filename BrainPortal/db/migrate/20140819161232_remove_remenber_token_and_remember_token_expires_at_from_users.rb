class RemoveRemenberTokenAndRememberTokenExpiresAtFromUsers < ActiveRecord::Migration
  def up
    remove_column :users, :remember_token
    remove_column :users, :remember_token_expires_at
  end

  def down
    add_column :users, :remember_token, :string
    add_column :users, :remember_token_expires_at, :datetime
  end
end
