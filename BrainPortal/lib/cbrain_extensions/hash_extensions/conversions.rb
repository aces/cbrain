
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
  module HashExtensions #:nodoc:

    # Hash conversion methods.
    module Conversions

      # This method allows you to perform a transformation
      # on all the keys of the hash; the keys are going to be passed
      # in turn to the block, and whatever the block returns
      # will be the new key. Example:
      #
      #   { "1" => "a", "2" => "b" }.convert_keys!(&:to_i)
      #
      #   returns
      #
      #   { 1 => "a", 2 => "b" }
      def convert_keys!
        self.keys.each do |key|
          self[yield(key)] = delete(key)
        end
        self
      end

      # Turns a hash table into a string suitable to be used
      # as HTML element attributes.
      #
      #   { "colspan" => 3, :style => "color: #ffffff", :x => '<>' }.to_html_attributes
      #
      # will return the string
      #
      #   'colspan="3" style="color: blue" x="&lt;&gt;"'
      def to_html_attributes
        self.map do |key, value|
          value = value.join(' ') if value.is_a?(Enumerable)
          next if value.blank? || key.blank?
          "#{key}=\"#{ERB::Util.html_escape(value)}\""
        end.join(' ')
      end

      # Filter a hash to remove sensitive info. Usually for params.
      # Will filter based on the +filter_parameters+ config of Rails.
      # This method was removed from Hash in Rails 5.1.
      def hide_filtered
        filtered_keys   = Rails.application.config.filter_parameters.presence || [ :password, :token, :ssh_key ]
        filter_object   = ActionDispatch::Http::ParameterFilter.new(filtered_keys)
        filter_object.filter(self.clone)
      end

      # For API calls that receive Hash objects,
      # we need the XML to use underscores instead of dashes.
      # If the hash was generated out of an ActiveRecord (e.g.
      # by the helper for_api() ) and it contains a 'type' attribute,
      # then we will also try to fetch the root of the STI hierarchy
      # for the XML root tag.
      # This generates and return such XML.
      def to_api_xml(options = {})
        root_tag   = self[:type] || self["type"]
        root_tag &&= root_tag.constantize.sti_root_class.name rescue nil
        to_xml({ :dasherize => false, :root => root_tag }.merge(options))
      end

      # Returns a dup of the hash, where the keys are sorted, and
      # any values that are arrays are also sorted. Applies these
      # rules recursively. Assumes that all keys and all array values
      # are things that can be compared, otherwise this will crash.
      def resorted
        res = self.class.new
        self.keys.sort.each do |key|
          val = self[key]
          if val.is_a?(Hash)
            res[key] = val.resorted
          elsif val.is_a?(Array)
            res[key] = val.sort.map { |x| x.respond_to?(:resorted) ? x.resorted : x }
          else
            res[key] = val
          end
        end
        res
      end

    end
  end
end


