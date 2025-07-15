
#
# CBRAIN Project
#
# Copyright (C) 2008-2022
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

# Controller for managing Quota objects.
# This controller (almost) indiscriminately manages
# both DiskQuota and CpuQuota objects. Many actions
# require a :mode parameter to indicate which (where
# the possible values are :disk or :cpu)
class QuotasController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required
  before_action :admin_role_required, :except => [ :index ]

  def index #:nodoc:
    @mode  = cbrain_session[:quota_mode].presence&.to_sym
    @mode  = :cpu  if params[:mode].to_s == 'cpu'
    @mode  = :disk if params[:mode].to_s == 'disk' || @mode != :cpu
    cbrain_session[:quota_mode] = @mode.to_s
    @scope = scope_from_session("#{@mode}_quotas#index")

    # Make sure the target user is set if viewing quotas for another user.
    @as_user                    = see_as_user params['as_user_id']
    @scope.custom['as_user_id'] = @as_user.id

    @base_scope   = base_scope.includes([:user, :data_provider  ]) if @mode == :disk
    @base_scope   = base_scope.includes([:user, :remote_resource]) if @mode == :cpu

    @view_scope = @scope.apply(@base_scope)

    @scope.pagination ||= Scope::Pagination.from_hash({ :per_page => 15 })
    @quotas = @scope.pagination.apply(@view_scope, api_request?)

    respond_to do |format|
      format.html
      format.js
    end
  end

  # Only available to admin. This is also an 'edit' and 'new' page
  def show #:nodoc:
    id     = params[:id]
    @quota = Quota.find(id)

    respond_to do |format|
      format.html
    end
  end

  # The 'new' action is special in this controller.
  #
  # For a disk quota, we accept a user_id and a data_provider_id as params;
  # the user_id can be 0 too.
  #
  # For a CPU quota, we accept a user_id, remote_resource_id and group_id as params;
  # any of them can be set to 0, but not all (see the CpuQuota model)
  #
  # A single potentially pre-existing object will be fetched OR
  # created depending on the values provided.
  def new
    user_id            = params[:user_id]           .presence || 0
    data_provider_id   = params[:data_provider_id]  .presence || 0 # only for disk quotas
    remote_resource_id = params[:remote_resource_id].presence || 0 # only for cpu quotas
    group_id           = params[:group_id]          .presence || 0 # only for cpu quotas

    @mode = params[:mode].to_s == 'cpu' ? :cpu : :disk
    model = @mode == :disk ? DiskQuota : CpuQuota

    data_provider_id   = nil if @mode == :cpu
    remote_resource_id = nil if @mode == :disk
    group_id           = nil if @mode == :disk

    atts = {
             :user_id            => user_id,
             :data_provider_id   => data_provider_id,
             :remote_resource_id => remote_resource_id,
             :group_id           => group_id,
           }

    # Try to find an existing quota record; nils will mean we fetch nothing
    @quota = model.where( atts ).first

    # If we haven't found an existing quota entry, we intialize a new one.
    # It can contain nils for the attributes.
    @quota ||= model.new( atts )

    render :action => :show # our show is also edit/create
  end

  # This method is also used for the +create+ action.
  #
  # This method is special in that only one instance of
  # a DiskQuota object is permitted to exist per pair of
  # user and data provider. In the same way, a single instance
  # of a CpuQuota object is permitted per triplet of
  # user, remote_resource and group.
  def update #:nodoc:
    id     = params[:id].presence # can be nil if we create() a new quota object
    @mode  = params[:mode].to_s == 'cpu' ? :cpu : :disk

    @quota = Quota.find(id) unless id.blank?
    if @quota
      # Set mode to sane version no matter what
      @mode = @quota.is_a?(DiskQuota) ? :disk : :cpu
    end

    model = @mode == :disk ? DiskQuota : CpuQuota

    # What we get from the POST/PUT/PATCH
    quota_params  = @mode == :disk ? disk_quota_params : cpu_quota_params
    form_user_id  = quota_params[:user_id].presence.to_i # turns nil into 0
    form_dp_id    = quota_params[:data_provider_id].presence.to_i
    form_rr_id    = quota_params[:remote_resource_id].presence.to_i
    form_group_id = quota_params[:group_id].presence.to_i

    if @mode == :disk
      atts = {
               :user_id            => form_user_id,
               :data_provider_id   => form_dp_id,
             }
    else # @mode == :cpu
      atts = {
               :user_id            => form_user_id,
               :remote_resource_id => form_rr_id,
               :group_id           => form_group_id,
             }
    end

    # Build the true object for the form
    @quota ||= model.where( atts ).first
    @quota ||= model.new(   atts )

    # Update the limits
    if @mode == :disk
      @quota.max_bytes = guess_size_units(quota_params[:max_bytes]) if quota_params[:max_bytes].present?
      @quota.max_files = quota_params[:max_files].to_i              if quota_params[:max_files].present?
    else # cpu quota
      @quota.max_cpu_past_week  = guess_time_units(quota_params[:max_cpu_past_week])  if quota_params[:max_cpu_past_week].present?
      @quota.max_cpu_past_month = guess_time_units(quota_params[:max_cpu_past_month]) if quota_params[:max_cpu_past_month].present?
      @quota.max_cpu_ever       = guess_time_units(quota_params[:max_cpu_ever])       if quota_params[:max_cpu_ever].present?
    end

    new_record = @quota.new_record?

    if @quota.save_with_logging(current_user, %w( max_bytes max_files max_cpu_past_week max_cpu_past_month max_cpu_ever ))
      if new_record
        flash[:notice] = "Quota entry was successfully created."
      else
        flash[:notice] = "Quota entry was successfully updated."
      end
      redirect_to quota_path(@quota)
      return
    end

    # Something went wrong, show edit page
    render :action => :show
  end

  # The create and update methods are the same.
  alias_method :create, :update #:nodoc:

  def destroy #:nodoc:
    id = params[:id]
    @quota = Quota.find(id)
    @quota.destroy

    flash[:notice] = "#{@quota.class.to_s.sub("Quota","")} quota entry deleted."

    if @quota.is_a?(DiskQuota)
      redirect_to quotas_path(:mode => 'disk')
    else # cpu
      redirect_to quotas_path(:mode => 'cpu')
    end
  end

  # Returns a list of users with exceeded quotas
  def report
    @mode = params[:mode].to_s == 'cpu' ? :cpu : :disk
    report_cpu_quotas  if @mode == :cpu
    report_disk_quotas if @mode == :disk
  end

  # Part of the report action, specifically for CpuQuotas
  def report_cpu_quotas

    past_week_all = Rails.cache.fetch("cpu_past_week", :expires_in => 10.minutes) do
      CputimeResourceUsageForCbrainTask
        .where('created_at > ?',1.week.ago)
        .group(:user_id,:remote_resource_id).sum(:value)
    end

    past_month_all = Rails.cache.fetch("cpu_past_month", :expires_in => 10.minutes) do
      CputimeResourceUsageForCbrainTask
        .where('created_at > ?',1.month.ago)
        .group(:user_id,:remote_resource_id).sum(:value)
    end

    ever_all = Rails.cache.fetch("cpu_ever", :expires_in => 10.minutes) do
      CputimeResourceUsageForCbrainTask
        .group(:user_id,:remote_resource_id).sum(:value)
    end

    # These two lamdas transform the hashes above into new hashes
    # where the top level is a UID (user or bourreau) and the key is
    # a hash with a subset of the entries for each. It's darn complicated.
    # For help, try this in Ruby shell:
    #  test_all = { [1,2] => 12, [3,4] => 34, [1,5] => 15, [3,5] => 35 }
    #  mk_by_uid.(test_all)
    mk_by_uid = ->(lw) { lw.inject({}) { |cumul,((u,b),t)| cumul[u] ||= {}; cumul[u][[u,b]] = t; cumul } } #woh

    # Make some optimized sublists
    past_week_by_uid  = mk_by_uid.(past_week_all)
    past_month_by_uid = mk_by_uid.(past_month_all)
    ever_by_uid       = mk_by_uid.(ever_all)

    # This is a searcher lambda; given 'past' is a hash with keys [u,b] and values v,
    # it will return all the [u,b]s for which the value v is greater than val
    search = ->(past, val) { (past || {}).keys.select { |ub| past[ub] >= val } }

    quota_to_excess = {}
    record = ->(quota, ub_list) { ent = quota_to_excess[quota] ||= {}; ub_list.each { |ub| ent[ub] = true } }

    CpuQuota.all.each do |quota|
      # Extract the six most important attributes of the quota object
      quid, qbid, qgid = quota.user_id, quota.remote_resource_id, quota.group_id
      max_week, max_month, max_ever = quota.max_cpu_past_week, quota.max_cpu_past_month, quota.max_cpu_ever

      if quota.is_for_user? && quota.is_for_resource?
        bad_week  = search.(past_week_by_uid[quid],  max_week) # array [ [user_id, bourreau_id], ... ]
        bad_month = search.(past_month_by_uid[quid], max_month)
        bad_ever  = search.(ever_by_uid[quid],       max_ever)
        bad_all   = (bad_week | bad_month | bad_ever).select { |u,b| b == qbid }
        record.(quota, bad_all) if bad_all.present?
        next
      end

      if quota.is_for_user?
        bad_week  = search.(past_week_by_uid[quid],  max_week) # array [ [user_id, bourreau_id], ... ]
        bad_month = search.(past_month_by_uid[quid], max_month)
        bad_ever  = search.(ever_by_uid[quid],       max_ever)
        bad_all   = (bad_week | bad_month | bad_ever)
        record.(quota, bad_all) if bad_all.present?
        next
      end

      # Prepare the list of users in a group, if we need it sigh
      all_uids_in_group = {}
      if quota.is_for_group?
        all_uids_in_group = Group.joins(:users).where('groups.id' => qgid).pluck('users.id')
          .index_by(&:itself)
      end

      # This handles all the other quota types
      bad_week  = search.(past_week_all,  max_week) # array [ [user_id, bourreau_id], ... ]
      bad_month = search.(past_month_all, max_month)
      bad_ever  = search.(ever_all,       max_ever)
      bad_all   = (bad_week | bad_month | bad_ever)
      bad_all   = bad_all.select { |u,b| all_uids_in_group[u]          } if quota.is_for_group?
      bad_all   = bad_all.select { |u,b| b == quota.remote_resource_id } if quota.is_for_resource?
      record.(quota, bad_all) if bad_all.present?
      next

    end # each quota object

    # Table content: [ [ user_id, bourreau_id, quota ], ... ]
    # Note: the rows are grouped by user_id, but not sorted in any way...
    @uid_bid_and_quota = []
    quota_to_excess.each do |quota,ub_list|
      ub_list.keys.each do |uid,bid|
        @uid_bid_and_quota << [ uid, bid, quota ]
      end
    end

    @uid_bid_and_quota.sort! # will sort the triplets by the first component, the user ID

  end

  # Part of the report action, specifically for DiskQuotas
  def report_disk_quotas #:nodoc:
    quota_to_user_ids = {}  # quota_obj => [uid, uid...]

    # Scan DP-wide quota objects
    DiskQuota.where(:user_id => 0).all.each do |quota|
      exceed_size_user_ids = Userfile
        .where(:data_provider_id => quota.data_provider_id)
        .group(:user_id)
        .sum(:size)
        .select { |user_id,size| size > 0 && size >= quota.max_bytes }
        .keys
      exceed_numfiles_user_ids = Userfile
        .where(:data_provider_id => quota.data_provider_id)
        .group(:user_id)
        .sum(:num_files)
        .select { |user_id,num_files| num_files > 0 && num_files >= quota.max_files }
        .keys
      union_ids  = exceed_size_user_ids | exceed_numfiles_user_ids
      union_ids -= DiskQuota
                   .where(:data_provider_id => quota.data_provider_id, :user_id => union_ids)
                   .pluck(:user_id) # remove user IDs that have their own quota records
      quota_to_user_ids[quota] = union_ids if union_ids.size > 0
    end

    # Scan user-specific quota objects
    DiskQuota.where('user_id > 0').all.each do |quota|
      quota_to_user_ids[quota] = [ quota.user_id ] if quota.exceeded?
    end

    # Inverse relation: user_id => [ quota, quota ]
    user_id_to_quotas = {}
    quota_to_user_ids.each do |quota,user_ids|
      user_ids.each do |user_id|
        user_id_to_quotas[user_id] ||= []
        user_id_to_quotas[user_id]  << quota
      end
    end

    # Table content: [ [ user_id, quota ], [user_id, quota] ... ]
    # Note: the rows are grouped by user_id, but not sorted in any way...
    @user_id_and_quota = []
    user_id_to_quotas.each do |user_id, quotas|
      quotas.each do |quota|
        @user_id_and_quota << [ user_id, quota ]
      end
    end

    @user_id_and_quota.sort! # will sort by the first component, the user ID

  end

  def report_almost
    @mode = params[:mode].to_s == 'cpu' ? :cpu : :disk
    cb_exception("not supported") if @mode == :cpu
    report_disk_almost if @mode == :disk
  end

  def report_disk_almost
    almost = 0.95 # share of resource use qualifying for 'almost exceeding'
    quota_to_user_ids = {}  # quota_obj => [uid, uid...]

    # Scan DP-wide quota objects
    DiskQuota.where(:user_id => 0).all.each do |quota|
      exceed_size_user_ids     = Userfile
                                   .where(:data_provider_id => quota.data_provider_id)
                                   .group(:user_id)
                                   .sum(:size)
                                   .select { |user_id,size| size >= quota.max_bytes * almost }
                                   .keys
      exceed_numfiles_user_ids = Userfile
                                   .where(:data_provider_id => quota.data_provider_id)
                                   .group(:user_id)
                                   .sum(:num_files)
                                   .select { |user_id,num_files| num_files >= quota.max_files * almost }
                                   .keys

      union_ids  = exceed_size_user_ids | exceed_numfiles_user_ids
      union_ids -= DiskQuota
                     .where(:data_provider_id => quota.data_provider_id, :user_id => union_ids)
                     .pluck(:user_id) # remove user IDs that have their own quota records
      quota_to_user_ids[quota] = union_ids if union_ids.size > 0
    end

    # Scan user-specific quota objects
    DiskQuota.where('user_id > 0').all.each do |quota|
      quota_to_user_ids[quota] = [ quota.user_id ] if quota.almost_exceeded?
    end

    # Inverse relation: user_id => [ quota, quota ]
    user_id_to_quotas = {}
    quota_to_user_ids.each do |quota,user_ids|
      user_ids.each do |user_id|
        user_id_to_quotas[user_id] ||= []
        user_id_to_quotas[user_id]  << quota
      end
    end

    # Table content: [ [ user_id, quota ], [user_id, quota] ... ]
    # Note: the rows are grouped by user_id, but not sorted in any way...
    @user_id_and_quota = []
    user_id_to_quotas.each do |user_id, quotas|
      quotas.each do |quota|
        @user_id_and_quota << [ user_id, quota ]
      end
    end

  end

  # a clone of browse_as
  def see_as_user(as_user_id) #:nodoc:
    scope     = scope_from_session("#{@mode}_quotas#index")
    users     = current_user.available_users
    as_user   = users.where(:id => as_user_id).first
    as_user ||= users.where(:id => scope.custom['as_user_id']).first
    as_user ||= current_user
    as_user
  end

  private

  def disk_quota_params #:nodoc:
    params.require(:quota).permit(
      :user_id, :data_provider_id,
      :max_bytes, :max_files,
    )
  end

  def cpu_quota_params #:nodoc:
    params.require(:quota).permit(
      :user_id, :remote_resource_id, :group_id,
      :max_cpu_past_week, :max_cpu_past_month, :max_cpu_ever,
    )
  end

  # Create list of quota records visible to current user.
  def base_scope #:nodoc:
    @mode ||= (params[:mode].to_s == 'cpu' ? :cpu : :disk)

    scope = DiskQuota.where(nil) if @mode == :disk
    scope = CpuQuota.where(nil)  if @mode == :cpu

    return scope if current_user.has_role?(:admin_user) && @as_user.id == current_user.id

    if @mode == :disk
      dp_ids = DataProvider.all.select { |dp| dp.can_be_accessed_by?(@as_user) }.map(&:id)
      scope = scope.where(
        :user_id          => [ 0, @as_user.id ],
        :data_provider_id => dp_ids,
      )
    end

    if @mode == :cpu
      rr_ids    = Bourreau.all.select { |b| b.can_be_accessed_by?(current_user) }.map(&:id)
      user_gids = current_user.group_ids
      scope = scope.where(
        :user_id            => [ 0, current_user.id ],
        :remote_resource_id => [ 0 ] + rr_ids,
        :group_id           => [ 0 ] + user_gids,
      )
    end

    scope
  end

  # Tries to turn strings like '3 mb' into 3_000_000 etc.
  # Supported suffixes are T, G, M, K, TB, GB, MB, KB, B (case insensitive).
  def guess_size_units(sizestring)
    match = sizestring.match(/\A\s*(-?\d*\.?\d+)\s*([tgmk]?)\s*b?\s*\z/i)
    return "" unless match # parsing error
    number = match[1]
    suffix = match[2].presence&.downcase || 'u'
    mult   = { 't' => 1_000_000_000_000, 'g' => 1_000_000_000, 'm' => 1_000_000, 'k' => 1_000, 'u' => 1 }
    totbytes = number.to_f * mult[suffix]
    totbytes = totbytes.to_i
    totbytes
  end

  # Tries to turn strings like '2h' into 7200 (for 7200 seconds, etc).
  # Supported suffixes are s, h, d, m, w, and y (case insensitive).
  # Minutes not supported because of the sad existance of months.
  def guess_time_units(timestring)
    match = timestring.match(/\A\s*(\d*\.?\d+)\s*([shdwmy]?)\s*\z/i)
    return "" unless match # parsing error
    number = match[1]
    suffix = match[2].presence&.downcase || 's'
    mult   = { 's' => 1.second, 'h' => 1.hour,  'd' => 1.day,
               'w' => 1.week,   'm' => 1.month, 'y' => 1.year, }
    tottime = number.to_f * mult[suffix].to_i
    tottime = tottime.to_i
    tottime
  end

end

