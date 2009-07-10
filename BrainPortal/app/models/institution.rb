
#
# CBRAIN Project
#
# Institution model
#
# Original author: Tarek Sherif
#
# $Id$
#

class Institution < ActiveRecord::Base

  Revision_info="$Id$"
  
  validates_presence_of   :name
  validates_uniqueness_of :name

end
