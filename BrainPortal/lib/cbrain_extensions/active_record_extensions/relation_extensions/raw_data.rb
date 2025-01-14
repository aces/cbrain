
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
    module RelationExtensions
      # ActiveRecord::Relation Added Behavior For Unstructured Data Fetches
      module RawData

        Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

        # Returns an array with just the first column of the
        # current relation. If an argument is given in +selected+,
        # then the relation is first modified with .select(selected)
        #
        #    User.where('login like "a%"').select(:login).raw_first_column
        #    => ["annie", "ahmed", "albator"]
        #
        #    User.where('login like "a%"').select(:id).raw_first_column
        #    => [3,4,7]
        #
        #    User.where('login like "a%"').raw_first_column(:id)
        #    => [3,4,7]
        #
        # This is basically a wrapper around the connection's
        # select_values() method (not to be confused with the
        # same method defined in ActiveRecord::Relation, which
        # does something completely different).
        def raw_first_column(selected = nil)
          modif = selected.present? ? self.select(selected) : self
          self.klass.connection.select_values(modif.to_sql)
        end

        # Returns an array of small arrays containing each record selected
        # by the current relation. If an argument is given in +selected+,
        # then the relation is first modified with .select(selected)
        #
        #    User.where('login like "a%"').select([:id,:login]).raw_rows
        #    => [[3, "annie"], [4, "ahmed"], [7, "albator"]]
        #
        #    User.where('login like "a%"').raw_rows([:id,:login])
        #    => [[3, "annie"], [4, "ahmed"], [7, "albator"]]
        #
        # This is basically a wrapper around the connection's
        # select_rows() method.
        def raw_rows(*args)
          selected = args.flatten
          modif = selected.present? ? self.select(selected) : self
          self.klass.connection.select_rows(modif.to_sql)
        end

      end
    end
  end
end
