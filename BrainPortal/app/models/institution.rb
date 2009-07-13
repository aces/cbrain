
#
# CBRAIN Project
#
# Institution model
#
# Original author: Tarek Sherif
#
# $Id$
#

#Model representing institutions. 
#=TODO: This model has become meaningless in the current structure of the system. Fix it.
#
#=Attributes:
#[*name*] A string representing a the name of the institution.
#[*city*] A string representing the city in which the institution is located.
#[*province*] A string representing the state/province in which the institution is located.
#[*coutry*] A string representing the country in which the institution is located..
class Institution < ActiveRecord::Base

  Revision_info="$Id$"
  
  validates_presence_of   :name
  validates_uniqueness_of :name

end
