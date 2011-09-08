
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

   Revision_info=CbrainFileRevision[__FILE__]

   attr_accessor :redirect
   attr_accessor :status
   
   #Initializer for CbrainException objects. The optional second argument
   #provides a url (or equivalent hash) to which the system will redirect the
   #request after the exception is handled.
   def initialize(message = "Something went wrong.", options = {})
     super(message)

     # Special feature of a CbrainException: it can carry a RAILS redirect directive.
     self.redirect = options[:redirect]
     self.status   = options[:status] || :ok
     
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

