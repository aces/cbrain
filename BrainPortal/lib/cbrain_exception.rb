
#
# CBRAIN Project
#
# $Id$
#

# This class provides the superclass for two CBRAIN-specific
# Exception classes, CbrainError and CbrainNotice. Unlike normal
# exceptions, their constructor can also take a second argument,
# a RAILS redirect structure.
class CbrainException < StandardError

   Revision_info="$Id$"

   attr_accessor :redirect

   def initialize(message = "Something went wrong.", redirect = nil)
     super(message)

     # Special feature of a CbrainException: it can carry a RAILS redirect directive.
     self.redirect = redirect

     # We remove the first two levels of the backtrace so that
     # when called from the new special methods cb_error() and cb_notice()
     # (added to Kernel in the initializers) we get a cleaner
     # trace.
     backtrace = caller
     backtrace.shift
     backtrace.shift
     self.set_backtrace(backtrace)

     self
   end

end

# Use this exception class for notification
# of problems within CBRAIN code.
class CbrainNotice < CbrainException
end

# Use this exception class for notification
# of serious errors within CBRAIN code.
class CbrainError < CbrainException
end

