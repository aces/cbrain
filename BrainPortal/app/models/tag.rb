
#
# CBRAIN Project
#
# Tag model
#
# Original author: Tarek Sherif
#
# $Id$
#

#Model representing User defined tags.
#
#=Attributes:
#[*name*] A string representing the name of the tag.
#= Associations:
#*Belongs* *to*:
#* User
#*Has* *and* *belongs* *to* *many*:
#* Userfile
class Tag < ActiveRecord::Base
  belongs_to              :user
  has_and_belongs_to_many :userfiles
  
  validates_presence_of   :name, :user_id
  validates_uniqueness_of :name, :scope => :user_id
  
  Revision_info="$Id$"
end
