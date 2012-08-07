
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

#= Portal Agent Locker Worker
#
# This class implements a worker that constantly relocks the
# SSH Agent for the CBRAIN system 20 seconds after any other part
# of the system has unlocked it. A single instance of this worker
# is expected to be started on the Portal side when the system boots.
class PortalAgentLocker < Worker

  Revision_info=CbrainFileRevision[__FILE__]

  def setup
    @agent         = SshAgent.find('portal') # our agent
    raise "No SSH agent found?" unless @agent

    # See CBRAIN.with_unlocked_agent for more info
    admin          = User.admin
    @passphrase    = admin.meta[:global_ssh_agent_lock_passphrase] ||= admin.send(:random_string)
    @passphrase_md = admin.meta.md_for_key(:global_ssh_agent_lock_passphrase)

    rr = RemoteResource.current_resource
    worker_log.info "#{rr.class.to_s} code rev. #{rr.revision_info.svn_id_rev} start rev. #{rr.info.starttime_revision}"

    @time_unlocked = nil # last time it was observed to be unlocked.
  end

  # Relocks the agent that was unlocked by CBRAIN.with_unlocked_agent() 
  def do_regular_work

    # Get keys from agent; a locked agent returns an empty list.
    keys = @agent.list_keys # this will raise an exception and properly terminate this worker if the agent is dead.
    if keys.empty?
      @time_unlocked = nil
      worker_log.debug "No keys, or already locked."
      return 
    end

    # OK, so how recently was it unlocked?
    @time_unlocked ||= Time.now.to_i # set the first time we encounter it unlocked
    @passphrase_md.reload
    md_date          =  @passphrase_md.updated_at.to_i # this timestamp updated by CBRAIN.with_unlocked_agent()
    @time_unlocked   = md_date if md_date > @time_unlocked # keep most recent of the two.

    if Time.now.to_i - @time_unlocked <= 20 # change too recent
      worker_log.debug "Agent unlocked, but too recently to lock again."
      return # postpone until next check
    end

    worker_log.info "Agent relocked."
    @agent.lock(@passphrase)

  rescue => ex

    worker_log.info "Got exception: #{ex.class}: #{ex.message}"
    worker_log.info "#{self.class} exiting"
    self.stop_me

  end

end
