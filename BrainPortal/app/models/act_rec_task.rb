
#
# CBRAIN Project
#
# Original author: Pierre Rioux
#
# $Id$
#


#
# This class is used to model DrmaaTasks as
# ActiveRecord objects on the Portal side (DrmaaTask is an ActiveResource)
# This doesn't really work well and was only created as a utility to help with
# certain migrations.
#
# = DO NOT USE THIS CLASS TO MANIPULATE 'DrmaaTask' ACTIVE RECORDS ON THE PORTAL SIDE!

class ActRecTask < ActiveRecord::Base

  Revision_info="$Id$"

  self.table_name = "drmaa_tasks"
  
  belongs_to  :bourreau
  belongs_to  :user

  serialize :params
  serialize :prerequisites

end
