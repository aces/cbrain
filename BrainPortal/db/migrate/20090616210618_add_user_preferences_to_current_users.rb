class AddUserPreferencesToCurrentUsers < ActiveRecord::Migration
  def self.up
    User.all.each do |user|
      unless user.user_preference
        UserPreference.create!(:user_id => user.id)
      end
    end
  end

end
