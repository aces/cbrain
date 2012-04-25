
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

# ActiveRecord extensions to handle loading and saving STI models.
# Mainly to load and create objects so they are of their actual STI
# +type+, and to get around automatic appending of type to DB queries.
module CBRAINExtensions
  module ActiveRecord
    module SingleTableInheritance
  
      def self.included(includer)
        includer.class_eval do
          extend ClassMethods
        end
      end
  
      # Perform operations in the block provided
      # without adding type information to queries.
      # The receiver is passed to the block provided
      # to allow for the following usage:
      #
      #    minc = MincFile.first
      #    minc.without_type_condition do |m|
      #      m.name = "I am minc"
      #      m.save
      #    end
      def without_type_condition
        self.class.without_type_condition do
          yield(self)
        end
      end
  
      # Subsequent +saves+ or +updates+ WILL NOT
      # include type conditions. 
      def no_type_condition_on_save!
        @__no_type_condition__ = true
      end
  
      # Subsequent +saves+ or +updates+ WILL
      # include type conditions.
      def type_condition_on_save!
        @__no_type_condition__ = false
      end
  
      private
      
      def create_or_update #:nodoc:
        if @__no_type_condition__
          without_type_condition do
            super
          end
        else
          super
        end
      end
  
      module ClassMethods
        
        # Find the root of this branch of the STI hierarchy.
        def sti_root_class
          return nil unless self < ::ActiveRecord::Base
          return class_variable_get("@@__sti_root_class__") if class_variable_defined?("@@__sti_root_class__")
  
          if self.superclass == ::ActiveRecord::Base
            root_class = self
          else
            root_class = ancestors.find{ |c| c.is_a?(Class) && c.superclass == ::ActiveRecord::Base }
          end
          root_class.class_variable_set("@@__sti_root_class__", root_class)
  
          root_class  
        end
  
        # Perform operations in the block provided
        # without adding type information to queries.
        def without_type_condition
          old_finder_needs_type_condition = nil
          class_eval do 
            old_finder_needs_type_condition = @finder_needs_type_condition
            @finder_needs_type_condition = :false 
          end
          yield
        ensure
          class_eval { @finder_needs_type_condition = old_finder_needs_type_condition }
        end
        
        # Create a new object with attributes set by +params+.
        # Object will be instantiated with class defined by
        # params[:type], if it's valid.
        #
        # The only option currently accepted is :include_root_class,
        # which considers the sti_root_class to be among the 
        # valid types.
        def sti_new(params = {}, options = {})
          prepare_sti_object(nil, params, options)
        end
        
        # Fetch a record from the database, set its
        # attributes using +params+, and set the class
        # to whatever's in params[:type], if it's 
        # provided.
        #
        # The only option currently accepted is :include_root_class,
        # which considers the sti_root_class to be among the 
        # valid types.
        def sti_load(id, params = {}, options = {})
          prepare_sti_object(id, params, options)
        end
        
        private
        # Can be used to intantiate or retrieve an object in the proper class
        # and set its attributes to prepare for saving for saving.
        def prepare_sti_object(id, params = {}, options = {})
          superklass = self.sti_root_class 
          valid_types = superklass.descendants.map(&:to_s)
          type_update = false
  
          if options[:include_root_class]
            valid_types << klass.to_s
          end
  
          type = params.delete :type 
  
          if type && valid_types.include?(type) 
            type_update = true
          end
  
          if type_update #Choose the class of the new object
            klass = type.constantize
          else
            klass = superklass
          end
  
          if id 
            object = superklass.find(id)
            if type_update # Make new model a copy of the old
              old_object = object
              object = klass.new
              old_object.attributes.each do |k, v|
                object.send("write_attribute", k, v)
              end
              object.instance_variable_set("@new_record", false)
            end
          else
            object = klass.new
          end
  
          if type_update
            object.type = type
          end
  
          object.attributes = params
          object.no_type_condition_on_save!
          
          object
        end
        
      end
      
    end
  end
end