
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

# Controller for the Service.
# Implement actions as defined by the CANARIE Web Service Monitoring API (deprecated).
#
# The only actions kept is the detailed_stats.
class ServiceController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  api_available

  # Return information about the usage of the platform.
  def detailed_stats
    @stats             = RemoteResource.current_resource.meta[:stats] || {}
    @stats_by_client   = @stats[:UserAgents] || {}
    @stats_by_contr_action = compile_total_stats(@stats)

    @last_reset        = (RemoteResource.current_resource.meta.md_for_key(:stats).created_at || Time.at(0)).utc.iso8601
    @stats[:lastReset] = @last_reset

    respond_to do |format|
      format.html
      format.xml  { render :xml  => @stats }
      format.json { render :json => @stats }
    end
  end

  private

  # From the raw stats accumulated for all clients,
  # controllers and actions, compile two other
  # secondary stats: the sums by clients, and
  # the sums by pair "controller,service".
  def compile_total_stats(stats={}) #:nodoc:
    stats_by_contr_action = {}

    # stats['AllAgents'] is { 'controller' => { 'action' => [1,2] , ... }, ... }
    all_agents = stats['AllAgents'] || stats[:AllAgents] || {}
    all_agents.each do |controller, by_action|
      by_action.each do |action, counts|
        # By controller and action
        contr_action = "#{controller},#{action}"
        stats_by_contr_action[contr_action]   ||= [0,0]
        stats_by_contr_action[contr_action][0] += counts[0]
        stats_by_contr_action[contr_action][1] += counts[1]
      end
    end

    return stats_by_contr_action
  end

end
