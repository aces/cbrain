
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

# To be included in ActiveRecord::Relation
#
# Makes it so finder methods always use +type_condition+, even if 
# class is set to not use type conditions.
#
# Can be overridden by calling +no_type_condition_affects_finders!+ 
# on the original class.
module CBRAINExtensions
  module ActiveRecord
    module MassAssignmentAuthorization
      
      Revision_info=CbrainFileRevision[__FILE__]
    
      # Redefine to_a because all finder methods go
      # through to_a.
      def self.included(includer) #:nodoc:
        includer.class_eval do
          attr_accessible
          attr_accessor :accessible
        end    
      end
      
      private

      def mass_assignment_authorizer
        if accessible == :all
          ActiveModel::MassAssignmentSecurity::BlackList.new(["id"])
        else
          super + (accessible || [])
        end
      end
       
    end
  end
end
