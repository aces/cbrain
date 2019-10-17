
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

  # Provides a graphical snapshot of activity

  def daily
   @range = 'Today' # for message at top
   gather_info(Time.now.at_beginning_of_day)
   render 'dashboard', :layout => false # full HTML layout already in view file
  end

  def weekly
   @range = 'This Week' # for message at top
   gather_info(Time.now.at_beginning_of_week)
   render 'dashboard', :layout => false # full HTML layout already in view file
  end

  def monthly
   @range = 'This Month' # for message at top
   gather_info(Time.now.at_beginning_of_month)
   render 'dashboard', :layout => false # full HTML layout already in view file
  end

  def yearly
   @range = 'This Year' # for message at top
   gather_info(Time.now.at_beginning_of_year)
   render 'dashboard', :layout => false # full HTML layout already in view file
  end

  private

  def gather_info(since_when) #:nodoc:

    # Bourreaux or DataProviders that are offline yet modified in the past
    # month will be shown in red even if they have no other activity.
    offline_resource_limit = 1.month # update date must be since that time ago

    # Zooper Sikrit params
    doroll           = params[:roll].presence
    @refresh_every   = params[:r].presence.try(:to_i)
    fake             = params[:fake].presence.try(:to_i) # fake statuses / offline / disk space etc

    # Auto refresh: default every two minutes.
    @refresh_every   = nil if @refresh_every.present? && @refresh_every < 10
    @refresh_every ||= 120.seconds

    # RemoteResources, including the portal itself
    @myself        = RemoteResource.current_resource
    @bourreaux     = Bourreau.where([ "updated_at > ?", offline_resource_limit.ago ]).order(:name).all # must have been toggled within a month

    # Some numbers: active users, active tasks, sum of files sizes being transferred, sum of CPU time
    @active_users  = CbrainSession.session_model
                       .where([ "updated_at > ?", since_when ])
                       .where(:active => true)
                       .raw_first_column(:user_id)
                       .compact.uniq.size
    @active_tasks  = CbrainTask.active.count
    @data_transfer = SyncStatus
                       .where("sync_status.status" => [ 'ToCache', 'ToProvider' ])
                       .joins(:userfile)
                       .sum("userfiles.size")
                       .to_i # because we sometimes get the string "0" ?!?
    @cpu_time      = CputimeResourceUsageForCbrainTask
                       .where([ "created_at > ?", since_when ])
                       .sum(:value)
    @space_delta_P = SpaceResourceUsageForUserfile
                       .where([ "created_at > ?", since_when ])
                       .where("value > 0")
                       .sum(:value)
    @space_delta_M = SpaceResourceUsageForUserfile
                       .where([ "created_at > ?", since_when ])
                       .where("value < 0")
                       .sum(:value)
    @space_delta   = @space_delta_P + @space_delta_M

    # This is used to adjust the color ranges
    @num_hours     = (Time.now - since_when) / 24.hours; @num_hours = 1.0 if @num_hours < 1

    # This is used to debug layout issues by generating random numbers
    if fake
      @active_users  = rand(fake)
      @active_tasks  = rand(fake)
      @data_transfer = rand(fake.gigabytes)
      @cpu_time      = rand(fake * 3600)
      @space_delta_P = rand(fake.gigabytes)
      @space_delta_M = - rand(fake.gigabytes)
      @space_delta   = @space_delta_P + @space_delta_M
    end

    # This is where we store all info for all bourreaux, keyed by ID
    @bourreau_info = {} # { b.id => { info => val, ... } }

    # We also scan the BrainPortal, although it has no tasks, because
    # the caching logic is the same.
    ([ @myself ] + @bourreaux ).each do |b| # b is a BrainPortal once, and a Bourreau for the rest
      info  = @bourreau_info[b.id] = {}

      # Sum of task workdir space
      info[:task_space] = b.is_a?(BrainPortal) ? 0 :
        b.cbrain_tasks.where(["updated_at > ?", since_when ])
                      .sum(:cluster_workdir_size)
                      .to_i

      # Count of active statuses
      info[:status_counts] = b.is_a?(BrainPortal) ? [] :
        b.cbrain_tasks.where(["updated_at > ?", since_when ])
                      .group(:status)
                      .count
                      .to_a  # [ [ status, count ], [ status, count ] ... ]

      # Size in caches (works for Bourreaux and BrainPortals)
      info[:cache_sizes] =
        SyncStatus.where(:remote_resource_id => b.id)
                  .where([ "sync_status.updated_at > ?", since_when ])
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
    @updated_files = Userfile.where([ "userfiles.updated_at > ?", since_when ])
                             .joins(:data_provider)
                             .order("data_providers.name")
                             .group("data_providers.id")
                             .sum("userfiles.size")
    # Add entries with 0 for DPs that happen to be offline, so we see still them in red.
    DataProvider.where(:online => false)
                .where(["updated_at > ?", offline_resource_limit.ago])
                .raw_first_column(:id)
                .each do |dpid|
      @updated_files[dpid] = 0 unless @updated_files[dpid].present?
    end

    if fake
      @updated_files = DataProvider.where({}).raw_first_column(:id).shuffle[0..rand(5)]
                                   .map { |dp| [ dp, rand(fake.gigabytes) ] }.to_h
    end

    # Trigger refresh using HTTP header.
    myurl  = "#{request.protocol}#{request.host_with_port}#{request.fullpath}"
    if doroll
      url_sequence = { 'daily' => 'weekly', 'weekly' => 'monthly', 'monthly' => 'daily' }
      myurl.sub!(/\/(daily|weekly|monthly)/) { |m| "/" + url_sequence[m.sub("/","")] }
    end
    response.headers["Refresh"] = "#{@refresh_every};#{myurl}"

    # Show IP address
    reqenv = request.env || {}
    @ip_address ||= cbrain_request_remote_ip rescue 'UnknownIP'

    # Number of exceptions
    @num_exceptions = ExceptionLog.where([ "created_at > ?", since_when ]).count
    @num_exceptions = rand(fake) if fake
  end

end
