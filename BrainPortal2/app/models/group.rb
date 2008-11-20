class Group < ActiveRecord::Base
  belongs_to              :institution
  has_and_belongs_to_many :users
  
  validates_presence_of :name, :institution_id
end
