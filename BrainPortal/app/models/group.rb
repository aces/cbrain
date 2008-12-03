
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

  belongs_to              :institution
  has_and_belongs_to_many :users
  belongs_to              :manager,
                          :class_name => 'User',
                          :foreign_key => 'manager_id'
  
  validates_presence_of :name, :institution_id
end
