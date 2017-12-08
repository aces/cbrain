
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
  module ParametersExtensions #:nodoc:

    # CBRAIN ActionController::Parameters utilities.
    module Utilities

      Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

      # This method acts exactly like the method +require+ of
      # ActionController::Parameters, for a single key, except
      # it returns a blank Parameters object in these two cases:
      #
      # - if the +key+ doesn't exist or
      # - +key+ does exist but its value is a blank Parameters
      #
      # The normal behavior of +require+ is to raise an exception
      # in these two cases.
      def require_as_params(key)
        return ActionController::Parameters.new() if ! self.has_key?(key)
        current_value = self[key]
        return current_value if
          current_value.is_a?(ActionController::Parameters) &&
          current_value.empty?
        self.require(key) # normal behavior
      end

    end
  end
end

