
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
  module ExceptionExtensions #:nodoc:

    # CBRAIN exceptions utilities.
    module Utilities

      # Returns the subset of a backrace that refers to the
      # actual CBRAIN code base, ignoring what's inside libraries etc.
      def cbrain_backtrace
        prefix = Rails.root.parent.to_s + "/"
        backtrace
          .select { |l| l =~ /\/(BrainPortal|Bourreau)\// }
          .map    { |l| l[prefix] = "" if l.start_with?(prefix); l }
      end

    end

  end
end
