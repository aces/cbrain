
#
# CBRAIN Project
#
# This class provides two CBRAIN-specific Exception
# classes. Unlike normal exceptions, their constructor
# can also take a second argument, a RAILS redirect structure.
#
# $Id$
#

class CbrainException < Exception
   attr_accessor :redirect

   def initialize(message = "Something went wrong.", redirect = nil)
     super(message)
     backtrace = caller
     backtrace.shift
     backtrace.shift
     self.redirect = redirect
     self.set_backtrace(backtrace)
     self
   end

end

class CbrainNotice < CbrainException
end

class CbrainError < CbrainException
end

# Raises a CbrainNotice exception, with a default redirect to
# the current controller's index action.
def cb_notify(message = "Something may have gone awry.", redirect = { :action  => :index } )
  raise CbrainNotice.new(message, redirect)
end
alias cb_notice cb_notify

# Raises a CbrainError exception, with a default redirect to
# the current controller's index action.
def cb_error(message = "Some error occured.",  redirect = { :action  => :index } )
  raise CbrainError.new(message, redirect)
end

