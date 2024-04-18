
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

  skip_before_action :check_if_locked
  before_action      :fetch_ip_address

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

  # Provides growth stats over time

  MONTHS_MAP = { '01' => 'Jan', '02' => 'Feb', '03' => 'Mar', '04' => 'Apr',
                 '05' => 'May', '06' => 'Jun', '07' => 'Jul', '08' => 'Aug',
                 '09' => 'Sep', '10' => 'Oct', '11' => 'Nov', '12' => 'Dec', }

  def users
    by       = params[:by].presence || 'year'
    @country = params[:country]     || 'Canada'

    creation_dates = User.order(:created_at)
#creation_dates = Userfile.order(:created_at)
    if by == 'month'
      creation_dates = creation_dates.where("created_at > ?",11.months.ago)
#creation_dates = User.order(:created_at) # debug, all time; month ordering and counts will all be merged weirdly
    end
    creation_dates_tot     = creation_dates.pluck(:created_at)
    creation_dates_country = creation_dates.where(:country => @country).pluck(:created_at)
#creation_dates_country = creation_dates.where(:type => 'TextFile').pluck(:created_at)

    count_method = (by == 'year') ? :dates_to_year_counts : :dates_to_month_counts
    @user_counts_tot      = send(count_method, creation_dates_tot)
    @user_counts_country  = send(count_method, creation_dates_country)

    if @user_counts_tot.empty?
      @user_counts_tot     = { "None" => 0 }
      @user_counts_country = { "None" => 0 }
    end

    # Counts for all countries other than the selected one
    # This is basically tot - country
    @user_counts_other = @user_counts_tot.map do |key,val|
       [ key, val - (@user_counts_country[key] || 0) ]
    end.to_h

    # Cumulative counts
    cumul = (by == 'year') ? 0 : User.where("created_at < ?",11.months.ago).count
    @user_counts_cumul = @user_counts_tot.map do |key,val|
      cumul += val; [ key, cumul ]
    end.to_h

    @max_val = @user_counts_cumul.values.max || 0
    @max_val = 1 if @max_val.zero?

    render 'users', :layout => false # full HTML layout already in view file
  end

  def cpu
    by = params[:by].presence || 'month'
    cputimes = CputimeResourceUsageForCbrainTask.order(:created_at)

    if by == 'year'
      start_range  = cputimes.first.created_at.beginning_of_year
      range_span   = 1.year
      range_render = lambda { |x| x.strftime("%Y") }
    else # if by == 'month'
      cputimes     = cputimes.where("created_at > ?",11.months.ago)
      start_range  = cputimes.first.created_at.beginning_of_month
      range_span   = 1.month
      range_render = lambda { |x| MONTHS_MAP[x.strftime("%m")] }
    end

    @cpu_tot = {}  # either "2021" => 123456 or "Feb" => 123456
    while start_range < Time.now
      end_range    = start_range + range_span
      cpu_in_range = cputimes.where("created_at > ? and created_at < ?",start_range,end_range).sum(:value)
      label        = range_render.(start_range)
      @cpu_tot[label] = cpu_in_range
#@cpu_tot[label] = rand(2) == 0 ? rand(1_000_000_000) : rand(1_000_000)
      start_range = end_range
    end

    @max_val = @cpu_tot.values.max || 0
    @max_val = 1 if @max_val.zero?

    render 'cpu', :layout => false # full HTML layout already in view file
  end

  # /noc/tools/:mode
  # /noc/tools/count
  # /noc/tools/cpu
  def tools
    range1   = params[:start].presence
    range2   = params[:end].presence
    range1 &&= DateTime.parse(range1) rescue nil
    range2 &&= DateTime.parse(range2) rescue nil

    tools  = CputimeResourceUsageForCbrainTask.order(:created_at)
    tools  = tools.where("created_at >= ?",range1) if range1
    tools  = tools.where("created_at <= ?",range2) if range2
    tools  = tools.group(:tool_name)

    @mode   = params[:mode].presence || 'count' # in URL
    @mode   = 'count' if @mode != 'cpu'

    tools  = tools.count       if @mode == 'count'
    tools  = tools.sum(:value) if @mode == 'cpu'

    pairs  = tools.to_a # [ [ toolname, val ], ... ]
    pairs.sort! { |p1,p2| p2[1] <=> p1[1] } # highest counts first

    @tools_stats = pairs  # either tool counts or tot cpu for each tool
    @max_val     = (@tools_stats.first || [nil, 1])[1]

    render 'tools', :layout => false # full HTML layout already in view file
  end

  private

  def dates_to_year_counts(timestamps)
    keys   = timestamps.map { |d| d.strftime("%Y") }
    counts = keys.hashed_partitions { |x| x }.transform_values { |v| v.size }
#(2022..2029).to_a.each { |y| counts[y.to_s] = rand(25) }
    counts
  end

  def dates_to_month_counts(timestamps)
    keys   = timestamps.map { |d| d.strftime("%m") }
    counts = keys.hashed_partitions { |x| x }.transform_values { |v| v.size }
    counts = counts.transform_keys  { |x| MONTHS_MAP[x] }
    counts
  end

  # This is for the main daily/monthly live monitor
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
    @dp_space_delta_P = SpaceResourceUsageForUserfile
                       .where([ "created_at > ?", since_when ])
                       .where("value > 0")
                       .group(:data_provider_id)
                       .sum(:value)
    @dp_space_delta_M = SpaceResourceUsageForUserfile
                       .where([ "created_at > ?", since_when ])
                       .where("value < 0")
                       .group(:data_provider_id)
                       .sum(:value)

    # This is used to adjust the color ranges
    @num_hours     = (Time.now - since_when) / 24.hours; @num_hours = 1.0 if @num_hours < 1

    # This is used to debug layout issues by generating random numbers
    if fake
      @active_users  = rand(fake)
      @active_tasks  = rand(fake)
      @data_transfer = rand(fake.gigabytes)
      @cpu_time      = rand(fake * 3600)
      @dp_space_delta_P = DataProvider.where({}).raw_first_column(:id).shuffle[0..rand(5)]
                                      .map { |dp| [ dp,   rand(fake.gigabytes) ] }.to_h
      @dp_space_delta_M = DataProvider.where({}).raw_first_column(:id).shuffle[0..rand(5)]
                                      .map { |dp| [ dp, - rand(fake.gigabytes) ] }.to_h
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
        b.cbrain_tasks.where(["updated_at > ? or status in (?)", since_when, CbrainTask::RUNNING_STATUS ])
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
    #@updated_files = Userfile.where([ "userfiles.updated_at > ?", since_when ])
    #                         .joins(:data_provider)
    #                         .order("data_providers.name")
    #                         .group("data_providers.id")
    #                         .sum("userfiles.size")
    # Add entries with 0 for DPs that happen to be offline, so we see still them in red.
    DataProvider.where(:online => false)
                .where(["updated_at > ?", offline_resource_limit.ago])
                .raw_first_column(:id)
                .each do |dpid|
    #  @updated_files[dpid]    = 0 unless @updated_files[dpid].present?
      @dp_space_delta_P[dpid] = 0 unless @dp_space_delta_P[dpid].present?
    end

    #if fake
    #  @updated_files = DataProvider.where({}).raw_first_column(:id).shuffle[0..rand(5)]
    #                               .map { |dp| [ dp, rand(fake.gigabytes) ] }.to_h
    #end

    # Trigger refresh using HTTP header.
    myurl  = "#{request.protocol}#{request.host_with_port}#{request.fullpath}"
    if doroll
      url_sequence = { 'daily' => 'weekly', 'weekly' => 'monthly', 'monthly' => 'daily' }
      myurl.sub!(/\/(daily|weekly|monthly)/) { |m| "/" + url_sequence[m.sub("/","")] }
    end
    response.headers["Refresh"] = "#{@refresh_every};#{myurl}"

    # Number of exceptions
    @num_exceptions = ExceptionLog.where([ "created_at > ?", since_when ]).count
    @num_exceptions = rand(fake) if fake

    # Number of BackgroundActivities (non scheduled) updated
    bacs = BackgroundActivity
      .where(:status => [ 'InProgress', 'Completed', 'Failed', 'PartiallyCompleted' ])
      .where([ "updated_at > ?", since_when ])
      .group(:status).count
    @num_bacs_progress  = bacs['InProgress']         || 0  # in blue
    @num_bacs_completed = bacs['Completed']          || 0  # in green
    @num_bacs_partial   = bacs['PartiallyCompleted'] || 0  # in yellow
    @num_bacs_failed    = bacs['Failed']             || 0  # in red

  end

  # Show IP address
  def fetch_ip_address
    reqenv = request.env || {}
    @ip_address ||= cbrain_request_remote_ip rescue 'UnknownIP'
  end

end
