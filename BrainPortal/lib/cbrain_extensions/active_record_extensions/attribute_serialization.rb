
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

module CbrainExtensions #:nodoc:
  module ActiveRecordExtensions #:nodoc:

    # ActiveRecord Added Behavior For Serialization of Attributes
    module AttributeSerialization

      Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

      def self.included(includer) #:nodoc:
        includer.class_eval do
          extend ClassMethods
        end
      end

      # Call this method in a :after_initialize callback. It will
      # check attributes that are supposed to be serialized as hash
      # with indifferent access. If they are, nothing happens. If they
      # happen to be ordinary hashes, they'll be upgraded.
      def ensure_serialized_hash_are_indifferent #:nodoc:
        to_update = {}
        attlist = self.class.indifferent_attributes.keys
        attlist.each do |att|
          the_hash = read_attribute(att) # value of serialized attribute, as reconstructed by ActiveRecord
          if the_hash.is_a?(Hash) && ! the_hash.is_a?(ActiveSupport::HashWithIndifferentAccess)
            #puts_blue "Oh oh, must fix #{self.class.name}-#{self.id} -> #{att} (#{the_hash.class})"
            #new_hash = ActiveSupport::HashWithIndifferentAccess.new_from_hash_copying_default(the_hash)
            new_hash = the_hash.with_indifferent_access
            to_update[att] = new_hash
          end
        end

        # Update it once and for all in the DB
        self.update(to_update) if to_update.present?

        true
      end

      module ClassMethods
        # This directive is just like ActiveRecord's serialize directive,
        # but it makes sure that the hash will be reconstructed as
        # a HashWithIndifferentAccess ; it is meant to be backwards compatible
        # with old DBs where the records were saved as Hash, so it will
        # update them as they are reloaded using a after_initialize callback.
        def serialize_as_indifferent_hash(*attlist)
          attlist.each do |att|
            raise "Attribute '#{att}' not a symbol?!?" unless att.is_a?(Symbol)
            indifferent_attributes[att] = true
            serialize att
          end
          after_initialize :ensure_serialized_hash_are_indifferent
        end

        # List of attributes that are stored as HashWithIndifferentAccess
        def indifferent_attributes
          @indifferent_attributes ||= (superclass.indifferent_attributes.cb_deep_clone rescue {}) || {}
        end
      end

    end
  end
end
