
#
# CBRAIN Project
#
# Model for user feedback resource
#
# Original author: Tarek Sherif
#
# $Id$
#

#Model representing the user feedback resource.
#
#=Attributes:
#[*summary*] A string representing a summary of the issue being raised in this entry.
#[*details*] Text with a detailed description of the issue being raised in this entry.
#= Associations:
#*Belongs* *to*:
#* User
class Feedback < ActiveRecord::Base

  Revision_info=CbrainFileRevision[__FILE__]

  belongs_to :user
  validates_presence_of     :details, :summary
  
end

