
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

module CBRAINExtensions #:nodoc:
  module ObjectExtensions #:nodoc:
    # Revision info access methods
    module RevisionTracking

      Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

      # This method returns the value of the object's class constant
      # named 'Revision_info', just like the class method of the
      # same name.
      def revision_info
        self.class.revision_info
      end

      def self.included(includer) #:nodoc:
        includer.class_eval do
          extend ClassMethods
        end
      end

      # Method to return the Revision_info object that holds
      # the history of the code file from git
      module ClassMethods

        # This method returns the value of the class constant
        # named 'Revision_info', if it exists; otherwise it
        # returns a default string in the same format
        def revision_info
          if self.const_defined?("Revision_info")
            self.const_get("Revision_info")
          else
            CbrainFileRevision.unknown_rev_info # dummy info object with dummy attributes
          end
        end

      end

    end
  end
end
