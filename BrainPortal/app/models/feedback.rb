
#
# CBRAIN Project
#
# Model for user feedback resource
#
# Original author: Tarek Sherif
#
# $Id$
#

class Feedback < ActiveRecord::Base
  belongs_to :user
  
  Revision_info="$Id$"
end
