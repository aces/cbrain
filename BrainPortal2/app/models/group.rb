class Group < ActiveRecord::Base
  belongs_to              :institution
  has_and_belongs_to_many :users
  belongs_to              :manager,
                          :class_name => 'User',
                          :foreign_key => 'manager_id'
  
  validates_presence_of :name, :institution_id
end
