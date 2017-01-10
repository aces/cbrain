class AddPrivateCommentToSignups < ActiveRecord::Migration
  def change
    add_column :signups, :admin_comment, :string
  end
end
