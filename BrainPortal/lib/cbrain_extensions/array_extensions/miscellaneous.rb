
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
  module ArrayExtensions #:nodoc:

    # Misc new array functions
    module Miscellaneous

      # Converts and array of ActiveRecord objects by invoking for_api() on
      # each of them. Returns the array of hash tables.
      def for_api
        map(&:for_api)
      end

      # Just like each_with_index(), but also provides the size of the array
      # in a third argument. This code:
      #
      #   x=('f'..'m').to_a
      #   x.each_with_index_and_size do |l,i,t|
      #     puts "#{i+1}/#{t} => #{l}"
      #   end
      #
      # will print:
      #
      #   1/8 => f
      #   2/8 => g
      #   3/8 => h
      #   4/8 => i
      #   5/8 => j
      #   6/8 => k
      #   7/8 => l
      #   8/8 => m
      def each_with_index_and_size
        each_with_index { |elem,idx| yield(elem,idx,size) }
      end

      # When invoked on an array of ActiveRecord objects,
      # or Hash objects obtained with for_api(),
      # creates the XML with underscores instead of dashes;
      # also will try to properly set the XML root tag to
      # represent the types of the objects in the array (using
      # the first object of the array to guess it). An array
      # of User objects would be rendered as
      #    "<Users><User>...</User>...</Users>"
      def to_api_xml(options = {})
        root_tag   = self[0].type    rescue nil
        root_tag ||= self[0][:type]  rescue nil
        root_tag ||= self[0]["type"] rescue nil
        root_tag &&= root_tag.constantize.sti_root_class.name rescue nil
        root_tag &&= root_tag.pluralize
        to_xml({ :dasherize => false, :root => root_tag }.merge(options))
      end

      # This method is a shorthand for self.for_api.to_api_xml
      def for_api_xml
        for_api.to_api_xml
      end

    end
  end
end

