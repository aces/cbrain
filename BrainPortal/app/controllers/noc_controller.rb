
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

    # Sicrit params
    @hours_ago       = params[:t].presence.try(:to_i)
    @refresh_every   = params[:r].presence.try(:to_i)
    fake             = params[:fake].presence.try(:to_i) # fake statuses / offline / disk space etc

    # Validate them, give them default
    @hours_ago       = nil if @hours_ago.present?     && @hours_ago < 1
    # Auto refresh: default every two minutes.
    @refresh_every   = nil if @refresh_every.present? && @refresh_every < 20
    @refresh_every ||= 120.seconds

    # Timescale for most reports: from midnight to right now.
    this_morning    = @hours_ago.try(:hours).try(:ago) || DateTime.now.midnight
    #this_morning = 7.years.ago # uncomment to artifically show all historical data

    # RemoteResources, including the portal itself
    @myself        = RemoteResource.current_resource
    @bourreaux     = Bourreau.where([ "updated_at > ?", 1.month.ago ]).order(:name).all # must have been toggled within a month

    # Three numbers: active users, active tasks, sum of files sizes being transfered.
    @active_users  = CbrainSession.where([ "updated_at > ?", this_morning ])
                                  .where(:active => true)
                                  .raw_first_column(:user_id)
                                  .compact.uniq.size
    @active_tasks  = CbrainTask.active.count
    @data_transfer = SyncStatus.where("sync_status.status" => [ 'ToCache', 'ToProvider' ])
                               .joins(:userfile)
                               .sum("userfiles.size")
                               .to_i # because we sometimes get the string "0" ?!?

    # This is used to debug layout issues by generating random numbers
    if fake
      @active_users  = rand(fake)
      @active_tasks  = rand(fake)
      @data_transfer = rand(fake.gigabytes)
    end

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

      # Size in caches (works for Bourreaux and BrainPortals)
      info[:cache_sizes] =
        SyncStatus.where(:remote_resource_id => b.id)
                  .where([ "sync_status.updated_at > ?", this_morning ])
                  .joins(:userfile)
                  .sum("userfiles.size")
                  .to_i # because we sometimes get the string "0"  ?!?

      # More fake info
      if fake
        info[:task_space]    = b.is_a?(BrainPortal) ? 0 : rand(fake.gigabytes)
        info[:cache_sizes]   =                            rand(fake.gigabytes)
        info[:status_counts] =
          CbrainTask::ALL_STATUS.shuffle[0..rand(10)].map { |s| [ s, rand(fake) ] }
      end

    end

    # Sizes of files updated, keyed by DP ID: { dp.id => size, ... }
    @updated_files = Userfile.where([ "userfiles.updated_at > ?", this_morning ])
                             .joins(:data_provider)
                             .order("data_providers.name")
                             .group("data_providers.id")
                             .sum("userfiles.size")
    if fake
      @updated_files = DataProvider.where({}).raw_first_column(:id).shuffle[0..rand(5)]
                                   .map { |dp| [ dp, rand(fake.gigabytes) ] }.to_h
    end

    # Trigger refresh using HTTP header.
    myurl  = "#{request.protocol}#{request.host_with_port}#{request.fullpath}"
    response.headers["Refresh"] = "#{@refresh_every};#{myurl}"

    # Show IP address
    reqenv = request.env || {}
    @ip_address ||= reqenv['HTTP_X_FORWARDED_FOR'] || reqenv['HTTP_X_REAL_IP'] || reqenv['REMOTE_ADDR'] || ""

    render :action => :daily, :layout => false # full HTML layout already in view file
  end

end
