
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

# This class implements a worker that constantly relocks the
# SSH Agent for the CBRAIN system N seconds (default: 60) after any other part
# of the system has unlocked it. A single instance of this worker
# is expected to be started on the Portal side when the system boots.
class PortalAgentLocker < Worker

  Revision_info=CbrainFileRevision[__FILE__]

  MaxUnlockTime=60 # independent of this worker's check_interval

  def setup #:nodoc:
    @agent         = SshAgent.find('portal') # our agent
    raise "No SSH agent found?" unless @agent

    # See CBRAIN.with_unlocked_agent for more info
    admin          = User.admin
    @passphrase    = admin.meta[:global_ssh_agent_lock_passphrase] ||= User.random_string

    # Who am I within CBRAIN?
    rr = RemoteResource.current_resource
    worker_log.info "#{rr.class.to_s} code rev. #{rr.revision_info.svn_id_rev} start rev. #{rr.info.starttime_revision}"

    @time_unlocked = nil # last time it was observed to be unlocked.

    # For statistics
    @sess_unlocked  = 0
    @cumul_unlocked = 0;
    @start_time     = Time.now.to_i
    @interval       = self.check_interval
    @half_int       = @interval / 2
    @cycle_count    = 0
  end

  # Relocks the agent that was unlocked by CBRAIN.with_unlocked_agent()
  def do_regular_work #:nodoc:

    @cycle_count += 1
    return if @cycle_count == 1 # we skip very first cycle, for better statistics.

    # Timestamp of most recent unlock event
    most_recent_unlocked = nil

    # Find all previous messages; this also sets most_recent_unlocked if found
    all_past_events      = SshAgentUnlockingEvent.order(:created_at).all
    most_recent_unlocked = all_past_events[-1].created_at if all_past_events.size > 0
#worker_log.debug "xxx MR0 #{most_recent_unlocked.presence || "(nil)"}"

    # Clean up all these messages; log them if we are in debug mode
    all_past_events.each do |ulockev|
      message = ulockev.message
      if message.present?
        worker_log.debug "Unlocked by: #{ulockev.to_log_entry}"
      else
        worker_log.warn "No reason found for unlocked agent! Date was: #{ulockev.created_at}"
      end
      ulockev.destroy
    end

    # Get keys from agent; a locked agent returns an empty list.
    keys = @agent.list_keys # this will raise an exception and properly terminate this worker if the agent is dead.
    if keys.empty?
      @time_unlocked = nil
      @sess_unlocked = 0
      worker_log.debug "No keys, or already locked."
      return
    end

    # Start adjusting statistics
    contrib = @time_unlocked.blank? ? @half_int : @interval # seconds unlocked contributed by latest cycle
    @cumul_unlocked += contrib
    @sess_unlocked  += contrib

    # OK, so how recently was the agent unlocked?
    @time_unlocked ||= Time.now.to_i # set the first time we encounter it unlocked
#worker_log.debug "xxx TU1 #{@time_unlocked}"
    @time_unlocked   = most_recent_unlocked.to_i if most_recent_unlocked.to_i > @time_unlocked # keep most recent of the two.
#worker_log.debug "xxx TU2 #{@time_unlocked}"
#worker_log.debug "xxx DIF #{Time.now.to_i - @time_unlocked}"

    if Time.now.to_i - @time_unlocked < MaxUnlockTime # change too recent
      worker_log.debug "Agent unlocked, but too recently to lock again. Session unlocked: #{@sess_unlocked} s."
      return # postpone until next check
    end

    @agent.lock(@passphrase)
    worker_log.info "Agent relocked. Agent was unlocked for #{@sess_unlocked} s."
    self.log_statistics
    @time_unlocked = nil
    @sess_unlocked = 0

  rescue => ex

    worker_log.info "Got exception: #{ex.class}: #{ex.message}"
    worker_log.info "#{self.class} exiting."
    self.stop_me

  end

  def finalize #:nodoc:
    self.log_statistics
  end

  def log_statistics #:nodoc:
    total_time       = Time.now.to_i - @start_time ; total_time = 1     if total_time < 1
    percent_unlocked = 100.0 * (@cumul_unlocked.to_f / total_time.to_f)
    pretty_percent   = sprintf("%.1f",percent_unlocked)
    worker_log.info "Total unlocked: #{@cumul_unlocked} s. ; Total time: #{total_time} s. ; Percent unlocked: #{pretty_percent} %"
  end

end
