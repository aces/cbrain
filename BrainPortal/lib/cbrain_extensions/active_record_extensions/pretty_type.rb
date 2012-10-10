
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
  module ActiveRecordExtensions #:nodoc:
    
    # ActiveRecord Added Behavior For Serialization
    module PrettyType
      
      Revision_info=CbrainFileRevision[__FILE__] #:nodoc:
      
      def self.included(includer) #:nodoc:
        includer.class_eval do
          extend ClassMethods
        end
      end

      
      # Default 'pretty' type name for the object.
      def pretty_type
        self.class.pretty_type
      end
      
      module ClassMethods
        # Default 'pretty' type name for the model.
        def pretty_type
          self.to_s.demodulize.underscore.titleize
        end
      end
      
    end
  end
end
