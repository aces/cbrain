
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

  def setup
    @myself    = RemoteResource.current_resource
    @myself_id = @myself.id
    worker_log.info "Starting BackgroundActivityWorker"
  end

  def main_process_is_alive?
    return true if is_proxy_alive?
    worker_log.info "#{@myself.name} process has exited, so I'm quitting too. So long!"
    self.stop_me
    false
  end

  # Calls process_task() regularly on any task that is ready.
  def do_regular_work

    return unless main_process_is_alive?

    BackgroundActivity.activate_scheduled(@myself_id)

    # All the activity ready on this CBRAIN component
    todo = BackgroundActivity.where(
      :remote_resource_id => @myself_id,
      :status             => 'InProgress'
    )

    worker_log.debug "Found #{todo.count} activities"

    # This is the 'dumb' first implementation of the
    # the processing loop.
    # A better implementation would avoid
    # locking and unlocking the same BA object
    # over and over when nothing else needs to be
    # done anyway.
    while todo.reload.count > 0
      break if stop_signal_received?

      # Optimization: while only 1 BA needs processing
      # we lock the record only once and keep processing
      # as long as no other BA shows up in the DB.
      if todo.count == 1
        theba = todo.first || break # disappeared?
        theba.get_lock     || break # someone else got it
        #worker_log.debug "SINGLE LOCK CODE"
        begin
          while theba.status == 'InProgress'
            theba.process_next_items_for_duration(5.seconds)
            break if todo.reload.count != 1
            break if stop_signal_received?
            # break unless main_process_is_alive?  # too costly?
          end
        ensure
          theba.remove_lock
        end
        next
      end

      break if stop_signal_received?

      # Round robin of multiple BAs. This requires more
      # locking and unlocking within the DB as we switch
      # from BA to BA.
      todo.reload.to_a.each do |ba| # a BackgroundActivity object
        #worker_log.debug "MULTI LOCK CODE #{todo.count}"
        ba.lock_yield_unlock do |theba|
          theba.process_next_items_for_duration(5.seconds)
        end
        break if stop_signal_received?
        break if todo.reload.count == 1 # this will bring us back to the optimized loop above
        #break unless main_process_is_alive?  # too costly?
      end

    end

    # Handle the case the worker process received a TERM
    # For the moment we just return with no other action
    return if stop_signal_received?
  end

end
