
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

    @base_scope = current_user.listable_groups.includes(:site)
    @view_scope = @scope.apply(@base_scope)

    @scope.pagination ||= Scope::Pagination.from_hash({ :per_page => 50 })
    @groups = @scope.pagination.apply(@view_scope)
    @groups = (@groups.to_a << 'ALL') if @scope.custom[:button]

    # For regular groups
    @group_id_2_userfile_counts      = Userfile.find_all_accessible_by_user(current_user, :access_requested => :read).group("group_id").count
    @group_id_2_task_counts          = CbrainTask.find_all_accessible_by_user(current_user).group("group_id").count
    @group_id_2_user_counts          = User.joins(:groups).group("group_id").count.convert_keys!(&:to_i) # .joins make keys as string
    @group_id_2_tool_counts          = Tool.find_all_accessible_by_user(current_user).group("group_id").count
    @group_id_2_data_provider_counts = DataProvider.find_all_accessible_by_user(current_user).group("group_id").count
    @group_id_2_bourreau_counts      = Bourreau.find_all_accessible_by_user(current_user).group("group_id").count
    @group_id_2_brain_portal_counts  = BrainPortal.find_all_accessible_by_user(current_user).group("group_id").count

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
    @group.user_ids |= [ current_user.id ] unless current_user.has_role?(:admin_user)
    unless @group.user_ids.blank?
      @group.user_ids &= current_user.available_users.map(&:id)
    end

    @group.creator_id = current_user.id

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

  def license_check
    return true if params[:id].blank?
    return true if params[:id] == 'all'
    # if unexpected id - let the action method handle the error message
    begin
      @group = current_user.viewable_groups.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      return true
    end
    if current_user.unsigned_custom_licenses(@group).present?
      flash[:error] = "Access to the project #{@group.name} is blocked due to licensing issues. Please consult with the project maintainer or support for details"
      license_redirect
    end
  end

end

