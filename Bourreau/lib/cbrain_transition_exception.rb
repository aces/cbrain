
#
# CBRAIN Project
#
# This class provides an exception class for
# representing a DrmaaTask state transition error.
#
# $Id$
#

class CbrainTransitionException < StandardError

   Revision_info="$Id$"

   attr_accessor :drmaa_task, :from_state, :to_state

end

