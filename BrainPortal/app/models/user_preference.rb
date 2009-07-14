#
# CBRAIN Project
#
# UserPreference model
#
# Original author: Tarek Sherif 
#
# $Id$
#

class UserPreference < ActiveRecord::Base

  Revision_info="$Id$"

  belongs_to  :user
  belongs_to  :data_provider
  belongs_to  :bourreau
  serialize   :other_options
  
  validates_presence_of   :user_id
  validates_uniqueness_of :user_id
  
  def update_options(options = {})
    self.other_options ||= {}
    self.other_options.merge!(options)
  end
  
  def before_create
    self.other_options ||= {}
  end
end
