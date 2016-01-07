
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

    # Convert array to hash based on given block.
    module HashedPartitions

      # Converts the array into a complex hash.
      # Runs the given block, passing it each of the
      # elements of the array; the block must return
      # a key that will be given to build a hash table.
      # The values of the hash table will be the list of
      # elements of the original array for which the block
      # returned the same key. The method returns the
      # final hash.
      #
      #   [0,1,2,3,4,5,6].hashed_partition { |n| n % 3 }
      #
      # will return
      #
      #   { 0 => [0,3,6], 1 => [1,4], 2 => [2,5] }
      #
      # The method also works with a block receiving two arguments,
      # the second one will be the index of the element in the array.
      #
      #   [ 'a', 'b', 'c', 'd'].hashed_partition { |n,i| i / 3 }
      #
      # will return
      #
      #   { 0 => ['a,'b','c'], 1 => ['d'] }
      def hashed_partition
        partitions = {}
        self.each_with_index do |elem,i|
           key = yield(elem,i)
           partitions[key] ||= []
           partitions[key] << elem
        end
        partitions
      end

      alias hashed_partitions            hashed_partition
      alias hashed_partition_with_index  hashed_partition
      alias hashed_partitions_with_index hashed_partition

    end
  end
end
