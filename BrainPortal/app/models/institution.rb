
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

  has_many :groups
  validates_presence_of :name

end
