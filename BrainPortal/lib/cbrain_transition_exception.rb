
#
# CBRAIN Project
#
# This class provides an exception class for
# representing a state transition error. Currently
# used on CbrainTask objects.
#
# $Id$
#

class CbrainTransitionException < StandardError

   Revision_info=CbrainFileRevision[__FILE__]

   attr_accessor :original_object, :from_state, :to_state, :found_state

end

