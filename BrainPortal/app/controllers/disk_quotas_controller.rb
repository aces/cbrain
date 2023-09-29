
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

# Controller for managing DiskQuota objects
class DiskQuotasController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required
  before_action :admin_role_required, :except => [ :index ]

  def index #:nodoc:
    @scope = scope_from_session

    # Browsing as a different user? Make sure the target user is set.
    @as_user                    = browse_as params['as_user_id']
    @scope.custom['as_user_id'] = @as_user.id  # can also be current user

    @base_scope = base_scope.includes([:user, :data_provider])
    @view_scope = @scope.apply(@base_scope)

    @scope.pagination ||= Scope::Pagination.from_hash({ :per_page => 15 })
    @disk_quotas = @scope.pagination.apply(@view_scope)

    respond_to do |format|
      format.html
      format.js
    end
  end

  # Only available to admin. This is also a 'edit' and 'new' page
  def show #:nodoc:
    id          = params[:id]
    @disk_quota = DiskQuota.find(id)

    respond_to do |format|
      format.html
    end
  end

  # The 'new' action is special in this controller.
  #
  # We accept a user_id and a data_provider_id as params;
  # the user_id can be 0 too.
  #
  # A single potentially pre-existing object will be fetched OR
  # created per pair of user_id and data_provider_id.
  def new
    user_id          = params[:user_id].presence
    data_provider_id = params[:data_provider_id].presence

    # Try to find an existing quota record; nils will mean we fetch nothing
    @disk_quota   = DiskQuota.where( :user_id => user_id, :data_provider_id => data_provider_id ).first

    # If we haven't found an existing quota entry, we intialize a new one.
    # It can contain nils for the attributes.
    @disk_quota ||= DiskQuota.new(   :user_id => user_id, :data_provider_id => data_provider_id )

    render :action => :show # our show is also edit/create
  end

  # This method is also used for the +create+ action.
  #
  # This method is special in that only one instance of
  # a quota object is permitted to exist per pair of user and data provider.
  def update #:nodoc:
    id                = params[:id].presence # can be nil if we create() a new quota object

    # What we get from the POST/PUT/PATCH
    quota_params      = disk_quota_params
    form_user_id      = quota_params[:user_id].to_i # turns nil into 0
    form_dp_id        = quota_params[:data_provider_id]

    # Build the true object for the form
    @disk_quota   = DiskQuota.find(id) unless id.blank?
    @disk_quota ||= DiskQuota.where( :user_id => form_user_id, :data_provider_id => form_dp_id ).first
    @disk_quota ||= DiskQuota.new(   :user_id => form_user_id, :data_provider_id => form_dp_id )

    # Update everything else.
    @disk_quota.max_bytes = guess_size_units(quota_params[:max_bytes]) if quota_params[:max_bytes].present?
    @disk_quota.max_files = quota_params[:max_files].to_i              if quota_params[:max_files].present?

    new_record = @disk_quota.new_record?

    if @disk_quota.save_with_logging(current_user, %w( max_bytes max_files ))
      if new_record
        flash[:notice] = "Disk Quota entry was successfully created."
      else
        flash[:notice] = "Disk Quota entry was successfully updated."
      end
      redirect_to disk_quota_path(@disk_quota)
      return
    end

    # Something went wrong, show edit page
    render :action => :show
  end

  # The create and update methods are the same.
  alias_method :create, :update #:nodoc:

  def destroy #:nodoc:
    id = params[:id]
    @disk_quota = DiskQuota.find(id)
    @disk_quota.destroy

    flash[:notice] = "Disk Quota entry deleted."

    redirect_to disk_quotas_path
  end

  # Returns a list of users with exceeded quotas
  def report #:nodoc:
    quota_to_user_ids = {}  # quota_obj => [uid, uid...]

    # Scan DP-wide quota objects
    DiskQuota.where(:user_id => 0).all.each do |quota|
      exceed_size_user_ids = Userfile
        .where(:data_provider_id => quota.data_provider_id)
        .group(:user_id)
        .sum(:size)
        .select { |user_id,size| size >= quota.max_bytes }
        .keys
      exceed_numfiles_user_ids = Userfile
        .where(:data_provider_id => quota.data_provider_id)
        .group(:user_id)
        .sum(:num_files)
        .select { |user_id,num_files| num_files >= quota.max_files }
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

  end

  # Returns a list of users exceeding and almost exceeded quotas
  def report_almost
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


  private

  # Browse the disc quota list as a user with id +as_user_id+
  def browse_as(as_user_id) #:nodoc:
    scope     = scope_from_session("disk_quota#browse")
    users     = current_user.available_users
    as_user   = users.where(:id => as_user_id).first
    as_user ||= users.where(:id => scope.custom['as_user_id']).first
    as_user ||= current_user
    as_user
  end

  def disk_quota_params #:nodoc:
    params.require(:disk_quota).permit(
      :user_id, :data_provider_id, :max_bytes, :max_files
    )
  end

  # Create list of quota records visible to current user.
  def base_scope #:nodoc:
    scope = DiskQuota.where(nil)
    unless current_user.has_role?(:admin_user)
      dp_ids = DataProvider.all.select do |dp|
        dp.can_be_accessed_by?(current_user) && dp.can_be_accessed_by?(@as_user)
      end.map(&:id)
      scope = scope.where(
        :data_provider_id => dp_ids,
        :user_id          => [ 0, current_user.id ],
      )
    end
    scope
  end

  # Tries to turn strings like '3 mb' into 3_000_000 etc.
  # Supported suffixes are T, G, M, K, TB, GB, MB, KB, B (case insensitive).
  # Negative values are parsed, but the DiskQuota model only accepts the special -1
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

end

