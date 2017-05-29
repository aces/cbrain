
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

    # ActiveRecord added behavior for whitelisting attributes
    # in a model when instances are sent through APIs.
    module ApiAttrVisible

      Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

      def self.included(includer) #:nodoc:
        includer.class_eval do
          extend ClassMethods
        end
      end

      module ClassMethods

        # Register a list of attributes to be whitelisted for the current model.
        # The :id attribute is implicit and always whitelisted.
        # Returns a hash table with attribute names as keys, and +true+ as values.
        #
        #   api_attr_visible :name, :description
        #
        # returns:
        #
        #   { :id => true, :name => true, :description => true }
        def api_attr_visible(*args)
          @api_attr_visible ||= { :id => true } # , :updated_at => true, :created_at => true }
          Array(args).each do |attr|
            raise "Argument '#{attr}' not a symbol or a proper attribute of the model." unless
              attr.is_a?(Symbol) && columns_hash.has_key?(attr.to_s)
            @api_attr_visible[attr] = true
          end
          @api_attr_visible
        end

        # Returns a list of whitelisted attributes which is the union
        # of the ones in the current class, and all those in the superclasses.
        def cumulative_api_attr_visible
          return @cumulative_api_attr_visible if @cumulative_api_attr_visible
          local_visible_list = api_attr_visible.keys
          super_visible_list = superclass.respond_to?(:cumulative_api_attr_visible) ? superclass.cumulative_api_attr_visible : []
          @cumulative_api_attr_visible = (local_visible_list | super_visible_list).map(&:to_s)
        end
      end

      # Returns a subset of the active record object's attributes,
      # for the attributes specified by api_attr_visible().
      # The return value is a hash, likely suitable for JSON serialization.
      def for_api
        visible_list = self.class.cumulative_api_attr_visible
        self.attributes.slice(*visible_list)
      end

    end
  end
end

