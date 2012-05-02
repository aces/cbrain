
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
    module SingleTableInheritanceFinders
    
      # Redefine to_a because all finder methods go
      # through to_a.
      def self.included(includer) #:nodoc:
        includer.class_eval do
          unless method_defined? :__old_to_a__
            
            alias :__old_to_a__ :to_a
            
            def to_a
              if klass.descends_from_active_record? || klass.finder_needs_type_condition? || klass.no_type_condition_affects_finders?
                __old_to_a__
              else
                where(klass.send(:type_condition)).send(:__old_to_a__)
              end
            end
            
          end
        end    
      end
      
    end
  end
end