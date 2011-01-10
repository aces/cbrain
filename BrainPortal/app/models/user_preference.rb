#
# CBRAIN Project
#
# UserPreference model
#
# Original author: Tarek Sherif 
#
# $Id$
#

#Model representing the preferences of a CBRAIN User. 
#
#=Attributes:
#[*other_options*] A hash used for any preferences not handled as an association
#                  (e.g. preferred arguments to launch a CbrainTask).
#= Associations:
#*Belongs* *to*:
#* User
#* DataProvider
#* Bourreau
class UserPreference < ActiveRecord::Base

  Revision_info="$Id$"

  validates_presence_of   :user_id
  validates_uniqueness_of :user_id
  
  belongs_to  :user
  belongs_to  :data_provider
  belongs_to  :bourreau
  serialize   :other_options
  
  #Meant to update the other_options hash en masse.
  #The +options+ hash will contain the preferences to 
  #update and their values, and these will be merged into
  #the current other_options hash. 
  def update_options(options = {})
    self.other_options ||= {}
    self.other_options.merge!(options)
  end
  
  #Initialize the other_options hash.
  def before_create #:nodoc:
    self.other_options ||= {}
  end
end
