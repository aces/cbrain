#
# CBRAIN Project
#
# Original author: Anton Zoubarev
#
# $Id$
#

# = WorkerPool
#
# This class is reponsible for providing worker pool management commands:
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
class WorkerPool

  Revision_info=CbrainFileRevision[__FILE__]

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

    cb_error "Needs a worker class that is a subclass of 'Worker'." if
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
    while (pool.workers.size < desired_number_of_workers) do
      worker = worker_class.new(initializers)
      worker.start
      pool.workers << worker
    end
    return pool
  end

  # Construct a pool for existing running workers of a certain class.
  def self.find_pool(worker_class)

    cb_error "Needs a worker class that is a subclass of 'Worker'." if
      ! worker_class.is_a?(Class) || ! (worker_class < Worker)

    pool = WorkerPool.new
    # Check if workers already exist.
    existing_workers = worker_class.find_existing_workers
    pool.workers.concat(existing_workers)
    return pool
  end

  # Wake up all workers in this pool.
  def wake_up_workers
    @workers.each { |worker| worker.wake_up }
  end

  # Stop all workers in this pool.
  def stop_workers
    @workers.each { |worker| worker.stop }
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
