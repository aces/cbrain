
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

#RESTful controller for the Group resource.
class GroupsController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include SwitchGroupHelpers

  api_available :only => [:index, :create, :switch, :update, :destroy, :show]

  before_action :login_required

  before_action :license_check, :only => [:show, :create, :switch, :edit, :update, :unregister, :destroy]

  # few license related attributes are updated here
  before_action :group_license_attributes, :only => [:show, :new_license, :add_license, :show_license, :sign_license]

  # GET /groups
  # GET /groups.xml
  def index  #:nodoc:
    @scope = scope_from_session
    scope_default_order(@scope, 'groups.name')

    params[:name_like].strip! if params[:name_like]
    scope_filter_from_params(@scope, :name_like, {
      :attribute => 'name',
      :operator  => 'match'
    })

    @scope.custom[:button] = true if
      current_user.has_role?(:normal_user) && @scope.custom[:button].nil?

    view_mode = (@scope.custom[:button].present?) ? :button : :list

    @base_scope = current_user.listable_groups.includes(:site)
    @view_scope = @scope.apply(@base_scope)

    if view_mode == :list
      @scope.pagination ||= Scope::Pagination.from_hash({ :per_page => 50 })
      @groups = @scope.pagination.apply(@view_scope, api_request?)
    else
      @groups = @view_scope.to_a
    end

    # For regular groups
    @group_id_2_userfile_counts      = Userfile.find_all_accessible_by_user(current_user, :access_requested => :read).group("group_id").count
    @group_id_2_task_counts          = CbrainTask.find_all_accessible_by_user(current_user).group("group_id").count
    @group_id_2_user_counts          = User.joins(:groups).group("group_id").count.convert_keys!(&:to_i) # .joins make keys as string

    # For `ALL` group
    @group_id_2_userfile_counts[nil] = Userfile.find_all_accessible_by_user(current_user, :access_requested => :read).count
    @group_id_2_task_counts[nil]     = current_user.available_tasks.count

    scope_to_session(@scope)

    respond_to do |format|
      format.js
      format.html # index.html.erb
      format.xml  { render :xml  => @groups.to_a.select { |x| x.is_a?(Group) }.for_api } # @groups can contain the string 'ALL'
      format.json { render :json => @groups.to_a.select { |x| x.is_a?(Group) }.for_api }
    end
  end

  # GET /groups/1
  # GET /groups/1.xml
  # GET /groups/1.json
  def show #:nodoc:
    @group = current_user.viewable_groups
    @group = @group.without_everyone if ! current_user.has_role? :admin_user
    @group = @group.find(params[:id])
    raise ActiveRecord::RecordNotFound unless @group.can_be_accessed_by?(current_user)
    @users = current_user.available_users.order(:login).reject { |u| u.class == CoreAdmin }

    respond_to do |format|
      format.html
      format.xml  { render :xml  => @group.for_api }
      format.json { render :json => @group.for_api }
    end
  end

  def new  #:nodoc:
    @group = WorkGroup.new
    @users = current_user.available_users.order(:login).reject { |u| u.class == CoreAdmin }
  end

  # POST /groups
  # POST /groups.xml
  # POST /groups.json
  def create  #:nodoc:
    @group = WorkGroup.new(group_params)

    # Normal users and Site Managers are always member of newly created group.
    unless current_user.has_role? :admin_user
      @group.site = current_user.site
    end

    # Final list of user IDs must intersect with list of available users for current user
    @group.creator_id = current_user.id
    @group.user_ids |= [ @group.creator_id ] # which is current_user
    @group.user_ids &= current_user.available_users.map(&:id)

    respond_to do |format|
      if @group.save
        @group.addlog_context(self,"Created by #{current_user.login}")
        flash[:notice] = 'Project was successfully created.'
        format.html { redirect_to :action => :index }
        format.xml  { render :xml  => @group.for_api, :status => :created }
        format.json { render :json => @group.for_api, :status => :created }
      else
        @users = current_user.available_users.where( "users.login<>'admin'" ).order( :login )
        format.html { render :new  }
        format.xml  { render :xml  => @group.errors, :status => :unprocessable_entity }
        format.json { render :json => @group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /groups/1
  # PUT /groups/1.xml
  # PUT /groups/1.json
  def update #:nodoc:
    @group = current_user.modifiable_groups.find(params[:id])

    unless @group.can_be_edited_by?(current_user)
       flash[:error] = "You don't have permission to edit this project."
       respond_to do |format|
        format.html { redirect_to :action => :show }
        format.xml  { head :forbidden }
        format.json { head :forbidden }
       end
       return
    end

    original_user_ids = @group.user_ids
    original_creator  = @group.creator_id

    new_group_attr    = group_params

    unless current_user.has_role? :admin_user
      new_group_attr[:site_id] = current_user.site_id
    end

    unless params[:update_users].present?
      new_group_attr[:user_ids] = @group.user_ids.map(&:to_s)
    end

    new_group_attr[:user_ids] ||= []

    unless new_group_attr[:user_ids].blank?
      if current_user.has_role? :normal_user
        new_group_attr[:user_ids] &= @group.user_ids.map(&:to_s)
      else
        new_group_attr[:user_ids] &= current_user.visible_users.map{ |u| u.id.to_s  }
      end
    end

    unless (current_user.available_users.map{ |u| u.id } | @group.user_ids).include?(new_group_attr[:creator_id].to_i )
      new_group_attr.delete :creator_id
    end

    @users = current_user.available_users.order(:login).reject { |u| u.class == CoreAdmin }

    # TODO FIXME This logic's crummy, refactor the adjustments outside the respond block!
    respond_to do |format|
      if @group.update_attributes_with_logging(new_group_attr,current_user)
        @group.reload
        add_meta_data_from_form(@group, [:autolink_description])
        if new_group_attr[:creator_id].present?
          @group.addlog_object_list_updated("Creator", User, original_creator, @group.creator_id, current_user, :login)
        end
        @group.user_ids |= [ @group.creator.id ]
        @group.addlog_object_list_updated("Users", User, original_user_ids, @group.user_ids, current_user, :login)
        flash[:notice] = 'Project was successfully updated.'
        format.html { redirect_to :action => "show" }
        format.xml  { head :ok }
        format.json { head :ok }
      else
        @group.reload
        format.html { render :action => "show" }
        format.xml  { render :xml  => @group.errors, :status => :unprocessable_entity }
        format.json { render :json => @group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # Used in order to remove a user from a group.
  def unregister
    @group = current_user.assignable_groups.where( :type => "WorkGroup" ).find(params[:id])

    respond_to do |format|
      if current_user.id == @group.creator_id
        flash[:error] = "You cannot be unregistered from a project you created."
        format.html { redirect_to group_path(@group) }
        format.xml  { head :unprocessable_entity }
        format.json { head :unprocessable_entity }
      else
        original_user_ids = @group.user_ids
        @group.user_ids   = @group.user_ids - [current_user.id]
        @group.addlog_object_list_updated("Users", User, original_user_ids, @group.user_ids, current_user, :login)

        flash[:notice] = "You have been unregistered from project #{@group.name}."
        format.html { redirect_to :action => "index" }
        format.xml  { head :ok }
        format.json { head :ok}
      end
    end
  end

  # DELETE /groups/1
  # DELETE /groups/1.xml
  # DELETE /groups/1.json
  def destroy  #:nodoc:
    @group = current_user.modifiable_groups.find(params[:id])
    if ! current_user.has_role?(:admin_user)
      cb_error "Cannot destroy this project: you are not its creator." if current_user.id != @group.creator_id
    end
    @group.destroy

    respond_to do |format|
      format.html { redirect_to :action => :index }
      format.js   { redirect_to :action => :index, :format => :js}
      format.xml  { head :ok }
      format.json { head :ok }
    end
  end

  def switch #:nodoc:

    group_id = params[:id]

    changed = switch_current_group(group_id)

    if changed
      remove_group_filters_for_files_and_tasks
      trigger_unselect_of_all_persistent_files

      if current_project
        scope_name = 'userfiles#index'
        userfiles_scope = scope_from_session(scope_name)
        userfiles_scope.custom[:view_all] = true if current_project.public?
        userfiles_scope.custom[:view_all] = true if current_project.creator_id != current_user.id
        scope_to_session(userfiles_scope, scope_name)
      end
    end

    if api_request?
      head :ok
    else
      redirect_to userfiles_path
    end
  end

  def license_redirect #:nodoc:
    respond_to do |format|
      format.html { redirect_to :action       => :index }
      format.any  { head        :unauthorized           }
    end
  end

  def new_license #:nodoc:
    cb_error "Only owner can set licensing", :redirect => { :action => :show } unless @can_add_license
  end

  def add_license #:nodoc:
    cb_error("Only owner can set licensing", :redirect => { :action => :show }) unless @can_add_license

    license_text = params[:license_text]
    cb_error 'Empty licenses are presently not allowed' if license_text.blank?

    timestamp  = Time.zone.now.strftime("%Y-%m-%dT%H:%M:%S")
    group_name = @group.name.gsub(/[^\w]+/, "")
    file_name  = "license_#{group_name}_#{timestamp}.txt"
    license    = @group.register_custom_license(license_text, current_user, file_name)
    current_user.signs_license_for_project(license, @group, model='group')

    flash[:notice] = 'A license is added. You can force users to sign multiple license agreements if needed.'
    redirect_to :action => :show
  end

  def show_license #:nodoc:
    # @group            =  @current_user.visible_groups.where(id: params[id]).first

    unsigned_licenses = current_user.unsigned_custom_licenses(@group)

    if unsigned_licenses.empty?
      if @current_licenses.present?
        flash[:notice] = 'You already signed all licenses'
      else
        flash[:notice] = 'No licenses are defined for this project'
        redirect_to :action => :show
        return
      end
    end

    # What to show. If a license is given in params,
    # we make sure it's a registered one and we pick that.
    @license_id = false unless @current_licenses.include? @license_id
    # If no valid license was given and there are unsigned licenses, pick the first
    @license_id ||= unsigned_licenses.first.try(:to_i)
    # Otherwise, show the first license.
    @license_id ||= @current_licenses.first

    # Load the text of the license
    userfile = Userfile.find(@license_id)
    userfile.sync_to_cache
    @license_text = userfile.cache_readhandle { |fh| fh.read }

    # Identifies if the current user has already signed it,
    # and whether they are the author
  end

  def sign_license #:nodoc:

    unless @group.custom_license_agreements.include?(@license_id)
      flash[:error] = 'You are trying to access unrelated license. Try again or report the issue to the support.'
      redirect_to :action => :show
      return
    end

    if @is_signed
      flash[:error] = 'You have already signed this license.'
      redirect_to :action => :show
      return
    end

    unless params.has_key?(:agree)
      flash[:error] = "You cannot access that project without signing the License Agreement first."
      redirect_to :action => :index
      return
    end

    if params[:license_check].blank? || params[:license_check].to_i == 0
      flash[:error] = "There was a problem with your submission. Please read the agreement and check the checkbox."
      redirect_to show_license_group_path(@group)
      return
    end

    license = Userfile.find(@license_id)
    current_user.signs_license_for_project(license, @group, model='group')

    if current_user.unsigned_custom_licenses(@group).empty?
      flash[:notice] = 'You signed all the project licenses'
    else
      flash[:notice] = 'This project has at least one other license agreement'
    end
    redirect_to :action => :show, :id => @group.id
  end

  # check license for project (group) with id pid,
  def license_check(pid=false)
    pid = pid || params[:id]


    return true if pid == 'all' ## to do && current_user.has_role(:admin)
    # if unexpected id - let the action method handle the error message
    begin
      @group = current_user.viewable_groups.find(pid)
    rescue ActiveRecord::RecordNotFound
      return true
    end
    if current_user.unsigned_custom_licenses(@group).present?
      flash[:error] = "Access to the project #{@group.name} is blocked due to licensing issues. Please sign the license"
      # license_redirect
      raise CbrainLicenseException
    end
  end

  private

  def group_params #:nodoc:
    if current_user.has_role?(:admin_user)
      params.require_as_params(:group).permit(
        :name, :description, :not_assignable,
        :site_id, :creator_id, :invisible, :track_usage,
        :public, :user_ids => []
      )
    else # non admin users
      params.require_as_params(:group).permit(
        :name, :description, :not_assignable,
        :public, :user_ids => []
      )
    end
  end

  def group_license_attributes # helper updates custom license attribute
    @group            = @current_user.viewable_groups.find(params[:id])
    @can_add_license  = current_user.id == @group&.creator_id
    @current_licenses = @group.custom_license_agreements

    param_lic_id = params['license_id'].presence
    @license_id  = param_lic_id && param_lic_id.to_i  # nil if param is nil-like, otherwise cast to integer
    @is_signed   = current_user.custom_licenses_signed.include?(@license_id)
  end

end

