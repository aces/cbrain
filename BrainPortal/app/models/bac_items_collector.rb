
#
# CBRAIN Project
#
# Copyright (C) 2008-2024
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

# This class provides a utility 'aggregator' or 'collector' for the
# list of items of BackgroundActivity (aka 'BAC') objects.
#
# The collector object is created and configured with
# a max number of items, and then the +add_items+ method
# can be invoked repetitively to add one or many items to a
# list maintained internally by the collector. Whenever that list
# exceeds in length the max number of items, a BAC object is created
# and saved to the database with that number of items.
#
# The collector is created by providing an existing BAC object (which doesn't
# even need to be saved to the database) as the model of all the BAC
# objects the collector will create. The collector keeps its own copy
# internally, and all attributes will be preserved except for the items
# list and the counters.
#
#   # Build a collector that creates a MoveFile BAC
#   # for every 5 items we push to it.
#   col = BacItemsCollector.new(
#     BackgroundActivity::MoveFile.new(
#       :user_id => 1,
#       :remote_resource_id => 1,
#       :status => 'InProgress',
#       :options => { :dest_data_provider_id => 45 }
#     ), 5)
#
#   # Push one item; the item will just be stored
#   # internally because we haven't reached the limit.
#   col.add_items(4)
#
#   # Push six more items in one go; this will trigger
#   # the creation of a MoveFile BAC with items 4,5,6,7,8
#   # while items 9, 10 remain in the collector.
#   col.add_items([5,6,7,8,9,10])
#
#   # Create a MoveFile BAC for the remaining two items.
#   col.flush
#
#   # Get a list of the IDs of all the BACs the collector
#   # has created so far.
#   bac_ids = col.submitted_bac_ids # array of IDs
#
class BacItemsCollector

  attr_reader :submitted_bac_ids, :max_items

  # Create a new collector object.
  #
  # +bac_template+ is a BackgroundActivity object representing exactly
  # what kind of object we want the collector to create over time,
  # as items accumulate. It doesn't have to be an object that exists in
  # the database (a new() object works just as well). All its attributes
  # must be properly initialized such that it COULD be saved, except
  # for the items list and the counters. The collector keeps its own
  # copy of the object, and resets the items and counters internally.
  #
  # The +max_items+ argument controls how many items needs to be provided
  # (using +add_items+) for the collector to create a BAC object.
  def initialize(bac_template,max_items)

    # We get a BackgroundActivity object that we will use as a template.
    # We initialize it to 'no items' and with counters at 0, but leave the rest alone.
    @bac            = bac_template.dup
    @bac.items      = []
    @bac.created_at = nil
    @bac.updated_at = nil
    @bac.reset!(@bac.status) # zap messages and counters

    # Some simple validations
    raise "The BackgroundActivity has no user_id."            unless @bac.user_id
    raise "The BackgroundActivity has no remote_resource_id." unless @bac.remote_resource_id
    raise "The BackgroundActivity has an invalid status."     unless
      [ 'InProgress', 'Scheduled', 'Suspended' ].include?(@bac.status)

    # How many items we pack in each BackgroundActivity object
    @max_items = max_items

    # List of submitted BackgroundActivity object IDs; this is
    # an attr_reader.
    @submitted_bac_ids = []

    self
  end

  # Add one or several items; items can be a single items or an array of items.
  # If the added items makes the collector's internal list of items exceed in length the parameter
  # max_items, then the collector will save its internal BAC object to the DB,
  # and prepare a new internal one for future items.
  #
  # The method will safely accept large arrays that trigger several such saves.
  #
  # Returns the number of items currently in the collector's memory.
  def add_items(items)
    new_items = Array(items)

    while @bac.items.size + new_items.size >= @max_items
      # Split max_items in BAC, leftover in new_items
      too_large_list = @bac.items + new_items # concatenate everything
      @bac.items = too_large_list[0..(@max_items-1)]
      new_items  = too_large_list[@max_items..-1]

      self.flush
    end

    # the partially filled @bac stays around in the object
    @bac.items += new_items

    @bac.items.size
  end

  # This method is like +add_items+ but the +item+ provided
  # must be a single item; if an array is provided, the
  # array itself will be added as a single item.
  #
  #  col << 34    # push the single item 34
  #  col << [1,2] # push the array [1,2] as a single item
  def <<(item)
    add_items( [ item ] )
  end

  # This method is like +add_items+ but the +items+ provided
  # must be an Enumerable. An exception will be raised
  # otherwise. Unlike +add_items+ this method returns self
  # (the BacItemsCollector object itelf). The recommended
  # way of using the "+" operator is through the "+=" operator
  # instead, even though this would also work with a bare "+".
  #
  #   col += [ 1, 2, 3]  # recommended
  #   col +  [ 1, 2, 3]  # NOT recommended; still updates col
  #
  def +(items)
    raise TypeError.new("BacItemsCollector requires an Enumerable for +=") unless items.is_a?(Enumerable)
    add_items(items)
    self
  end

  # Invoke this method to 'flush' the remaining items,
  # when the final slice of items doesn't fill up to max_items.
  #
  # Returns the number of items that was in the BAC that
  # was saved (zero if no BAC was created).
  def flush
    # Save BAC with current list of items; does nothing if the items list is empty
    bac_saved = @bac.dup
    bac_saved.save! if bac_saved.items.size > 0
    @submitted_bac_ids << bac_saved.id if bac_saved.id

    # Reset current BAC to empty
    @bac.items = []

    bac_saved.items.size
  end

  # Utility method that allows you to query
  # the collector and get the number of items
  # currently in the internal queue.
  def number_of_items_pending
    @bac.items.size
  end

end
