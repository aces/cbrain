
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
      # ActiveRecord::Relation safety net to avoid OOM conditions when trying
      # to invoke +inspect+ on very large relations.
      module SafeInspect

        Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

        # Keep the original +inspect+ method available
        alias :original_inspect :inspect

        def cbrain_sql_inspect(*args) #:nodoc:
          "#<#{self.class}:0x#{self.object_id.to_s(16)} #{self.to_sql}>"
        end

        # Behaves just like +inspect+, but will throw a NoMemoryError instead of
        # eating up tons of memory if the relation would return (and try) to
        # instantiate too many records. Note that this monkey-patch is mainly
        # intended for development and debugging purposes, and might be too
        # restrictive; in some cases, invoking +inspect+ is fine even with a
        # high record count.
        #
        # The method is also used to override the default inspect() in other
        # classes, even when there isn't a risk of a large number of objects.
        def inspect(*args)
          return self.cbrain_sql_inspect(*args) unless self.respond_to?(:count) && self.count > 5000

          raise NoMemoryError.new("#{self.to_s} is too large to be inspected")
        end
      end
    end
  end
end
