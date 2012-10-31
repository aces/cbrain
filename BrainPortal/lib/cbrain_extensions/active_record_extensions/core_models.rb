
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
    
    # Allow models to be marked as undestroyable.
    module CoreModels
      
      Revision_info=CbrainFileRevision[__FILE__] #:nodoc:
      
      def self.included(includer) #:nodoc:
        includer.class_eval do
          extend ClassMethods
        end
      end
      
      def core_model?
        self.class.core_model?
      end
      
      module ClassMethods

        def core_model?
          @cbrain_core_model ||= false
        end
        
        private
        # Default 'pretty' type name for the model.
        
        def core_model!
          @cbrain_core_model = true
          define_method :prevent_destruction do
            raise CbrainDeleteRestrictionError.new("CBRAIN core models cannot be destroyed!")
          end
            
          before_destroy :prevent_destruction
        end
      end
      
    end
  end
end
