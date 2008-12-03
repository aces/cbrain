class Tag < ActiveRecord::Base
  belongs_to              :user
  has_and_belongs_to_many :userfiles
  
  validates_presence_of   :name, :user_id
  validates_uniqueness_of :name, :scope => :user_id
end
