
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
      
      def make_accessible(*args)
        @accessible_attributes = [] unless @accessible_attributes.is_a?(Array)
        @accessible_attributes += args
      end
      
      def make_all_accessible
        @accessible_attributes = :all
      end
      
      private

      def mass_assignment_authorizer
        if @accessible_attributes == :all
          ActiveModel::MassAssignmentSecurity::BlackList.new(["id"])
        else
          super + (@accessible_attributes || [])
        end
      end
       
    end
  end
end
