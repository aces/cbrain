class SignupsTweaks < ActiveRecord::Migration
  def up
    change_column :signups, :admin_comment, :text
    change_column :signups, :comment, :text
    add_column    :signups, :user_id, :integer
    add_column    :signups, :hidden, :boolean, :default => false

    Signup.all.each do |d|
      user = User.where(:login => d.login).first
      if user.present?
        user[:signup_id] = user.id
        user.save
      end
    end
  end

  def down
    remove_column :signups, :user_id
    remove_column :signups, :hidden
  end
end
