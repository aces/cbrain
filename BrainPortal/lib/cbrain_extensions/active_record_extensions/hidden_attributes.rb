
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

    # ActiveRecord Added Behavior For Temporarily Hiding Attributes
    module HiddenAttributes

      Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

      # When invoked on an active record object, hides the values
      # of all attributes listed in attr_list (an array of symbols).
      # Fetching their values will return instead either "N/A" (default)
      # or the custom value supplied in options[:replacement].
      # The object's save() and save!() methods will be overridden
      # to raise an exception ActiveRecord::RecordNotSaved
      def hide_attributes(attr_list, options={})
        newvalue = options.has_key?(:replacement) ? options[:replacement] : "N/A"
        attr_list.each { |attr| self[attr] = newvalue }
        raise_not_saved = lambda do |*attr|
           raise ActiveRecord::RecordNotSaved.new("This object has hidden attributes and cannot be saved")
        end
        define_singleton_method :save,  raise_not_saved
        define_singleton_method :save!, raise_not_saved
        true
      end

    end
  end
end
