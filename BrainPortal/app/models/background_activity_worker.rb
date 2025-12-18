
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

class BackgroundActivityWorker < Worker

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # How much time to process a BAC before switching to another BAC.
  # Currently hardcoded, maybe one day it will be configurable.
  BAC_SLICE_TIME=15.seconds

  # Any BAC that had a lock on it and has not been updated in
  # this amount of time is considered 'dead' (process died?)
  BAC_IS_DEAD_TIME=12.hours

  def setup
    @myself    = RemoteResource.current_resource
    @myself_id = @myself.id
    worker_log.info "Starting BackgroundActivityWorker"
  end

  def main_process_is_alive?
    return true if @myself.is_a?(BrainPortal) # On a portal, we don't care
    return true if is_proxy_alive?
    worker_log.info "#{@myself.name} process has exited, so I'm quitting too. So long!"
    self.stop_me
    false
  end

  # Adds a log entry for the worker with information about
  # the BackgroundActivity object +bac+ , like this:
  #
  #   "Completed BACType by username: 3 x OK, 0 x Fail"
  #
  # This method is mostly called when a BAC changes from
  # "InProgress" to anything else.
  def log_bac(bac)
    status = bac.status
    login  = bac.user.login
    type   = bac.class.to_s.demodulize
    counts = "#{bac.num_successes} x OK, #{bac.num_failures} x Fail"
    worker_log.info "#{status} #{type} by #{login}: #{counts}"
  end

  # Calls process_task() regularly on any task that is ready.
  def do_regular_work

    return unless main_process_is_alive?

    # Initial handling of BACs as we wake up:
    # 1) those that were scheduled and are now ready
    BackgroundActivity.activate_scheduled(@myself_id)
    # 2) those that are crashed
    BackgroundActivity.cancel_crashed(@myself_id, BAC_IS_DEAD_TIME)

    # All the activity ready on this CBRAIN component
    todo_base = BackgroundActivity.where(
      :remote_resource_id => @myself_id,
      :status             => 'InProgress',
      :handler_lock       => nil,
    )
    todo = todo_base  # this is a complex relation, stupid start_at !
            .where(:start_at => nil)
            .or(todo_base.where("start_at < ?",Time.now))

    worker_log.debug "Found #{todo.count} activities"

    # Timestamp we use to check for BAC activation every 5 minutes at most
    last_activation = Time.now # matches the activate_scheduled() just above

    # Loop for round robin of all active BACs.
    while todo.count > 0
      todo.reload.each do |bac| # a BackgroundActivity object
        bac.lock_yield_unlock do |thebac|
          thebac.process_next_items_for_duration(BAC_SLICE_TIME) # at least 5 seconds
        end
        log_bac(bac) if bac.status != 'InProgress'

        return if     stop_signal_received?  # will just end the do_regular_work()
        return unless main_process_is_alive? # a bit costly?

        # Every minute, check if new BACs happen to be ready
        if last_activation < 1.minute.ago
          BackgroundActivity.activate_scheduled(@myself_id)
          last_activation = Time.now
        end
      end # loop on each BAC currently active
    end # while there is anything to do at all
  end

end
