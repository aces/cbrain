#
# CBRAIN Project
#
# Tool controller for the BrainPortal interface
#
# Original author: Angela McCloskey
#
# Revision_info="$Id$"
#

#Model representing CBrain tools. 
#The purpose of the tools model is to create an inventory of the tools for each bourreau.
#
#=Attributes:
#[*tool_name*] The name of the tool.
#[*user_id*] The owner of the tool.
#[*group_id*] The group that the tool belongs to.
#[*category*]  The category that the tool belongs to.
#= Associations:
#*Belongs* *to*:
#* User
#* Group
#*Has* *and* *belongs* *to* *many*
#* Bourreau
class Tool < ActiveRecord::Base
  Revision_info="$Id$"
  
  belongs_to :user
  belongs_to :group
  has_and_belongs_to_many :bourreaux
  
  validates_uniqueness_of :tool_name
  
end
