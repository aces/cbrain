
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

# Network Operation Center controller
# Basically just shows status information.
class NocController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Provides a graphical daily snapshot of activity
  def daily
    this_morning   = DateTime.now.midnight
    refresh_every  = 120.seconds
    #this_morning = 7.years.ago # uncomment to artifically show all historical data

    @myself        = RemoteResource.current_resource
    @bourreaux     = Bourreau.where([ "updated_at > ?", 1.month.ago ]).order(:name).all # must have been toggled within a month

    # Three numbers: active users, active tasks, sum of files sizes being transfered.
    @active_users  = CbrainSession.where([ "updated_at > ?", Time.now.midnight ])
                                  .where(:active => true)
                                  .raw_first_column(:user_id)
                                  .uniq.size
    @active_tasks  = CbrainTask.active.count
    @data_transfer = SyncStatus.where("sync_status.status" => [ 'ToCache', 'ToProvider' ])
                               .joins(:userfile)
                               .sum("userfiles.size")
                               .to_i # because we sometimes get the string "0" ?!?

    #@active_tasks = rand(500)  # uncomment to make visual tests
    #@data_transfer = rand(500_000_000_000)  # uncomment to make visual tests

    # This is where we store all info for all bourreaux, keyed by ID
    @bourreau_info = {} # { b.id => { info => val, ... } }

    # We also scan the BrainPortal, although it has no tasks, because
    # the caching logic is the same.
    ([ @myself ] + @bourreaux ).each do |b| # b is a BrainPortal once, and a Bourreau for the rest
      info  = @bourreau_info[b.id] = {}

      # Sum of task workdir space
      info[:task_space] = b.is_a?(BrainPortal) ? 0 :
        b.cbrain_tasks.where(["updated_at > ?",this_morning])
                      .sum(:cluster_workdir_size)
                      .to_i

      # Count of active statuses
      info[:status_counts] = b.is_a?(BrainPortal) ? [] :
        b.cbrain_tasks.where(["updated_at > ?",this_morning])
                      .group(:status)
                      .count
                      .to_a  # [ [ status, count ], [ status, count ] ... ]
      # Uncomment these two lines to generate fake statuses for visual tests
      #info[:status_counts] =
      #CbrainTask::ALL_STATUS.shuffle[0..rand(10)].map { |s| [ s, rand(1000) ] }

      # Size in caches (works for Bourreaux and BrainPortals)
      info[:cache_sizes] =
        SyncStatus.where(:remote_resource_id => b.id)
                  .where([ "sync_status.updated_at > ?", this_morning ])
                  .joins(:userfile)
                  .sum("userfiles.size")
                  .to_i # because we sometimes get the string "0"  ?!?
    end

    # Sizes of files updated, keyed by DP ID: { dp.id => size, ... }
    @updated_files = Userfile.where([ "userfiles.updated_at > ?", this_morning ])
                             .joins(:data_provider)
                             .order("data_providers.name")
                             .group("data_providers.id")
                             .sum("userfiles.size")

    # Trigger refresh using HTTP header.
    myurl = "#{request.protocol}#{request.host_with_port}#{request.fullpath}"
    response.headers["Refresh"] = "#{refresh_every};#{myurl}"

    render :action => :daily, :layout => false # layout already in view file
  end

end
