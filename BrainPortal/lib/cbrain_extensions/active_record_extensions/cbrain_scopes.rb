
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

    # Restore +scopes+ method behaviour that was lost in Rails 3.1
    module CbrainScopes

      Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

      def self.included(includer) #:nodoc:
        includer.class_eval do
          extend ClassMethods
        end
      end


      module ClassMethods
        def cb_scopes #:nodoc:
          @cb_scopes ||= defined?(super) ? super.cb_deep_clone : {}
        end

        private

        def cb_scope(scope_name, *args) #:nodoc:
          cb_scopes[scope_name] = args
          scope(scope_name, *args)
        end
      end

    end
  end
end
