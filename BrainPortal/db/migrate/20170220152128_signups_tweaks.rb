class SignupsTweaks < ActiveRecord::Migration
  def up
    change_column :signups, :admin_comment, :text
    change_column :signups, :comment, :text
    add_column    :signups, :user_id, :integer
    add_column    :signups, :hidden, :boolean, :default => false

    Signup.where(:user_id => nil).all
      .select { |d| d.login.present? && d.approved? }
      .each do |d|
        if user = User.where(:login => d.login).first
          puts "Adjusting link: Signup ##{d.id} #{d.full} created user: #{user.login}"
          d.user_id = user.id
          d.save
        end
    end
  end

  def down
    remove_column :signups, :user_id
    remove_column :signups, :hidden
  end
end
