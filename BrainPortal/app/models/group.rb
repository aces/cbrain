
#
# CBRAIN Project
#
# Group model
#
# Original author: Tarek Sherif
#
# $Id$
#

#Model representing the Group resource. Groups are meant to represented collective access
#to certain files (analogous to groups of the Unix OS).
#
#=Attributes:
#[*name*] A string representing the name of the group.
#= Associations:
#*Has* *and* *belongs* *to* *many*:
#* User
#*Has* *many*:
#* Userfile
class Group < ActiveRecord::Base

  Revision_info="$Id$"

  has_and_belongs_to_many :users 
  has_many                :userfiles    

  validates_presence_of   :name
  validates_uniqueness_of :name
end
