
#
# CBRAIN Project
#
# Group model
#
# Original author: Tarek Sherif
#
# $Id$
#

class Group < ActiveRecord::Base

  Revision_info="$Id$"

  #A-Many groups belong to many insitutions
  #has_and_belongs_to_many :institutions

  #A-many groups and many userfiles

  has_and_belongs_to_many :users 

  has_many                :userfiles  
  
  #A-again possibly take this out
  #belongs_to              :manager,
  #                        :class_name => 'User',
  #                        :foreign_key => 'manager_id'
  #A-take this out

  validates_presence_of   :name
  validates_uniqueness_of :name
end
