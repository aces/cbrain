class AddUserPreferencesToCurrentUsers < ActiveRecord::Migration
  def self.up
    User.all.each do |user|
      unless user.user_preference
        UserPreference.create!(:user_id => user.id, :data_provider_id => DataProvider.first.id, :bourreau_id => CBRAIN_CLUSTERS::CBRAIN_cluster_list[0])
      end
    end
  end

end
