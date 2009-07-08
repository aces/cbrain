
#
# CBRAIN Project
#
# The class to model the drmaa_tasks table as
# ActiveRecord on the Portal side (because the
# class DrmaaTask is an ActiveResource!)
#
# This doesn't really work well and is only used
# for certain migrations.
#
# DO NOT USE THIS CLASS TO MANIPULATE 'DrmaaTask'
# ACTIVE RECORDS ON THE PORTAL SIDE!
#
# Original author: Pierre Rioux
#
# $Id$
#

class ActRecTask < ActiveRecord::Base

  Revision_info="$Id$"

  self.table_name = "drmaa_tasks"

  serialize :params

private
  # This is an overidde of the ActiveResource method
  # used to instanciate objects while ignoring
  # the 'type' column, so all objects are 'ActRecTask's.
  def self.instantiate(record)
    if record.has_key?("type")
      subtype = record.delete("type")
    end
    super(record)
  end

end
