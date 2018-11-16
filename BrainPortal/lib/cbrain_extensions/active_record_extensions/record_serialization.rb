
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

    # ActiveRecord Added Behavior For Serialization of Records
    module RecordSerialization

      Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

      #def self.included(includer) #:nodoc:
      #  includer.class_eval do
      #    extend ClassMethods
      #  end
      #end

      # For API calls that receive ActiveRecord objects,
      # we need the XML to use underscores instead of dashes.
      # Also, we want the root tag to be the root of the
      # single table inheritance hierarchy.
      # This generates and return such XML.
      def to_api_xml(options = {})
        to_xml({ :dasherize => false, :root => self.class.sti_root_class.name }.merge(options))
      end

      # This method is a shorthand for self.for_api.to_api_xml
      def for_api_xml
        for_api.to_api_xml
      end

      #module ClassMethods
      #end

    end
  end
end
