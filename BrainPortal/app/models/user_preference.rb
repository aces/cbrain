class UserPreference < ActiveRecord::Base
  belongs_to  :user
  belongs_to  :data_provider
  serialize   :other_options
  
  validates_presence_of :user_id
  
  def update_options(options = {})
    self.other_options ||= {}
    self.other_options.merge!(options)
  end
end
