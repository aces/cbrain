
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

# = WorkerPool
#
# This class is responsible for providing worker pool management commands:
# [create_or_find_pool] Creates a pool of workers if it cannot find ones already running. Created workers are automatically started.
# [wake_up_workers]     Wakes up all workers in the pool.
# [stop_workers]        Terminates all workers in the pool.
#
# == Usage:
#
#  bourreau_workers = WorkerPool.create_or_find_pool(MyWorkerClass, 5, { :name => "Abc" } )
#  bourreau_workers.wake_up_workers # if needed
#  bourreau_workers.stop
#
# WARNING: Current limitation is that only 1 pool is allowed per Worker subclass.
#
# Original author: Anton Zoubarev
class WorkerPool

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # The array of workers in the pool.
  attr_accessor :workers #TODO: read only?

  def initialize #:nodoc:
    @workers=[]
  end

  # This method returns a pool with specified +desired_number_of_workers+
  # First it attempts to find existing running workers of specified class,
  # it creates additional or kills extra workers if needed. If an
  # +initializers+ hash is provided, it will be passed to each Worker's
  # initializer.
  def self.create_or_find_pool(worker_class, desired_number_of_workers, initializers = {})

    raise "Needs a worker class that is a subclass of 'Worker'." if
      ! worker_class.is_a?(Class) || ! (worker_class < Worker)

    pool = WorkerPool.new

    # Check if workers already exist.
    existing_workers = worker_class.find_existing_workers
    pool.workers.concat(existing_workers)

    # Kill extra workers if needed.
    while (pool.workers.size > desired_number_of_workers) do
      worker = pool.workers.pop
      worker.stop
    end

    # Create additional workers if needed.
    delay = 0
    while (pool.workers.size < desired_number_of_workers) do
      worker = worker_class.new(initializers)
      worker.start
      pool.workers << worker
      delay = 3
    end
    sleep delay if delay > 0
    return pool
  end

  # Construct a pool for existing running workers of a certain class.
  def self.find_pool(worker_class)

    raise "Needs a worker class that is a subclass of 'Worker'." if
      ! worker_class.is_a?(Class) || ! (worker_class < Worker)

    pool = WorkerPool.new
    # Check if workers already exist.
    existing_workers = worker_class.find_existing_workers
    pool.workers.concat(existing_workers)
    return pool
  end

  # Wake up all workers in this pool.
  def wake_up_workers
    @workers.each { |worker| worker.wake_up rescue true }
  end

  # Stop all workers in this pool.
  def stop_workers
    @workers.each { |worker| worker.stop rescue true }
  end

  # Utility method that acts like Array's each(), for each worker
  # in the pool.
  def each
    @workers.each { |worker| yield worker }
  end

  # Utility method that acts like Array's size(), returning the
  # number of workers in the pool.
  # in the pool.
  def size
    @workers.size
  end

end
