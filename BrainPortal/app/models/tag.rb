
#
# CBRAIN Project
#
# Tag model
#
# Original author: Tarek Sherif
#
# $Id$
#

#Model representing user-defined tags.
#
#=Attributes:
#[*name*] A string representing the name of the tag.
#= Associations:
#*Belongs* *to*:
#* User
#*Has* *and* *belongs* *to* *many*:
#* Userfile
class Tag < ActiveRecord::Base

  Revision_info=CbrainFileRevision[__FILE__]

  validates_presence_of   :name, :user_id, :group_id
  validates_uniqueness_of :name, :scope => :group_id
  validates_format_of     :name,  :with => /^[\w\-\=\.\+\?\!\s]*$/, 
                                  :message  => 'only the following characters are valid: alphanumeric characters, spaces, _, -, =, +, ., ?, !'
  
  has_and_belongs_to_many :userfiles
  belongs_to              :user
  belongs_to              :group

end

