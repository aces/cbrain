
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
    module RelationExtensions #:nodoc:
      # ActiveRecord::Relation Added Behavior For API Requests
      module ForApiRequests

        Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

        DEFAULT_API_LIMIT = 100 #:nodoc:

        # When invoked on a relation, this method will first check to see
        # if it is limited. If not, it will impose a limit (configurable by
        # model using the default_api_limit() method) and then return the
        # relation through .to_a().for_api() to generate an array of
        # API-acceptable records.
        def for_api
          rel = self
          rel = rel.limit(rel.model.default_api_limit || DEFAULT_API_LIMIT) unless rel.limit_value
          rel.to_a.for_api
        end

        # This method is a shorthand for self.for_api.to_api_xml
        def for_api_xml
          for_api.to_api_xml
        end

      end
    end
  end
end
