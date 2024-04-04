
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

class BackgroundActivitiesController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required
  before_action :admin_role_required,  :only => [:new, :create, :destroy]

  # Admin only, HTML only
  def new #:nodoc:
    @bac         = BackgroundActivity.new
    @bac.user_id = current_user.id
  end

  # Admin only, HTML only
  def create #:nodoc:
    @bac = BackgroundActivity.new(base_bac_params).class_update
    @bac.status    = 'Scheduled'
    @bac.options   = {}
    @bac.configure_for_dynamic_items!

    @bac.errors.add(:type, "is not a proper type") if @bac.class == BackgroundActivity # exact test

    # Parse starts time
    spar = schedule_params
    @start_date, @start_hour, @start_min = spar[:start_date], spar[:start_hour], spar[:start_min]
    datestring = "#{@start_date} #{@start_hour}:#{@start_min}"
    @bac.start_at = nil
    if datestring =~ /\A(20[23]\d?-\d\d-\d\d|\d\d\/\d\d\/20[23]\d) \d\d:\d\d\z/
      start = DateTime.parse(datestring + " " + DateTime.now.zone) rescue nil
      start = nil if start < Time.now || start > 6.months.from_now
      @bac.start_at = start
    end
    @bac.errors.add(:base, "Start date or time is invalid (no past date and max six months ahead)") if @bac.start_at.blank?

    # Parse repeat pattern
    @repeat, @repeat_hour, @repeat_min = spar[:repeat], spar[:repeat_hour], spar[:repeat_min]
    repeat  = @repeat
    repeat += "#{@repeat_hour}:#{@repeat_min}" if repeat.ends_with? '@'
    @bac.repeat = repeat

    # Configure type-specific options
    add_options_for_random_activity    if @bac.is_a?(BackgroundActivity::RandomActivity)
    add_options_for_compress_file      if @bac.is_a?(BackgroundActivity::CompressFile) || @bac.is_a?(BackgroundActivity::UncompressFile)
    add_options_for_move_file          if @bac.is_a?(BackgroundActivity::MoveFile)     || @bac.is_a?(BackgroundActivity::CopyFile)
    add_options_for_archive_task       if @bac.is_a?(BackgroundActivity::ArchiveTaskWorkdir)

    if (@bac.errors.present?) || (! @bac.valid?) || (! @bac.save)
      render :action => :new
      return
    end
    redirect_to :action => :index
  end

  # GET /background_activities
  def index #:nodoc:
    @scope = scope_from_session
    @base_scope = BackgroundActivity.all.includes( [:user, :remote_resource] )
    if ! current_user.has_role? :admin_user
      @base_scope = @base_scope.where(:user_id => current_user.id)
    end
    @view_scope = @bacs = @scope.apply(@base_scope)
    scope_to_session(@scope)

    respond_to do |format|
      format.html # index.html.erb
      format.js
      format.json  { render :json => @bacs.to_a }
    end
  end

  # POST /background_activities/operation
  def operation #:nodoc:
    # It's quite stupid but we detect the type of operation
    # based on the value returned by the submit button
    op      = :cancel!    if params[:commit] =~ /cancel/i
    op      = :suspend!   if params[:commit] =~ /\bsuspend/i
    op      = :unsuspend! if params[:commit] =~ /unsuspend/i
    op      = :destroy    if params[:commit] =~ /destroy/i
    bac_ids = Array(params[:bac_ids])
    bacs = BackgroundActivity.where(:id => bac_ids)
    bacs = bacs.where(:user_id => current_user.id) if ! current_user.has_role? :admin_user
    bacs = bacs.to_a.select { |bac| bac.send(op) }
    # These messages are clumsy
    flash[:notice] = "#{bacs.size} activities affected by #{op.to_s.gsub(/\W/,"")}." if bacs.size  > 0
    flash[:notice] = "No activities affected."  if bacs.size == 0
    redirect_to :action => :index
  end

  protected

  def base_bac_params
    params
      .require_as_params(:background_activity)
      .permit %w(
        user_id remote_resource_id type
      )
  end

  def schedule_params
    params.permit %w( start_date start_hour  start_min
                      repeat     repeat_hour repeat_min )
  end

  def params_options
    params.require_as_params(:background_activity).require_as_params(:options)
  end

  def add_options_for_random_activity
    opt = params_options.permit( :mintime, :maxtime, :count_ok, :count_fail, :count_exc )
    max_0_20 = ->(str,min=0) { val=str.to_i; val < min ? min : val > 20 ? 20 : val }
    @bac.setup(
      max_0_20.(opt[:mintime],0),
      max_0_20.(opt[:maxtime],1),
      max_0_20.(opt[:count_ok]),
      max_0_20.(opt[:count_fail]),
      max_0_20.(opt[:count_exc]),
    )
    @bac.errors.add(:base, "Test activity doesn't have any items?") if @bac.items.size == 0
    @bac.options = opt.to_h # just for form persistency; these values aren't used in the BAC
  end

  # This code makes a bunch of verification so that the ID
  # really is the ID of a custom filter owned by the current user
  def add_options_for_compress_file
    opt       = params_options.permit( :userfile_custom_filter_id )
    filter_id = opt[:userfile_custom_filter_id]
    filter    = UserfileCustomFilter.where(:user_id => current_user.id).find(filter_id)
    @bac.options[:userfile_custom_filter_id] = filter.id
  end

  # Also use for Copy File
  def add_options_for_move_file #:nodoc:
    @move_file_dp_id = params[:move_file_dp_id]
    @move_crush      = params[:move_crush].present?
    @bac.options[:dest_data_provider_id] = @move_file_dp_id
    @bac.options[:crush_destination]     = @move_crush
  end

  # Also use for Copy File
  def add_options_for_archive_task #:nodoc:
    @archive_task_dp_id = params[:archive_task_dp_id]
    @bac.options[:archive_data_provider_id] = @archive_task_dp_id.presence # can be nil
  end

end
