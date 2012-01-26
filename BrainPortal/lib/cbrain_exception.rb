
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.  
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
     backtrace.shift(options[:shift_caller]) if options[:shift_caller]
     self.set_backtrace(backtrace)

     self
   end

end

