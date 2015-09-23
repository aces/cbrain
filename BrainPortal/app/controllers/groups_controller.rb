
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

  before_filter :login_required

  # GET /groups
  # GET /groups.xml
  def index  #:nodoc:
    @scope = scope_from_session('groups')
    scope_default_order(@scope, 'groups.name')

    params[:name_like].strip! if params[:name_like]
    scope_filter_from_params(@scope, :name_like, {
      :attribute => 'name',
      :operator  => 'match'
    })

    @scope.custom[:button] = true if
      current_user.has_role?(:normal_user) && @scope.custom[:button].nil?

    @base_scope = current_user.available_groups.includes(:site)
    @view_scope = @scope.apply(@base_scope)

    @scope.pagination ||= Scope::Pagination.from_hash({ :per_page => 50 })
    @groups = @scope.pagination.apply(@view_scope)
    @groups = (@groups.to_a << 'ALL') if @scope.custom[:button]

    @group_id_2_userfile_counts = Userfile.group("group_id").count
    @group_id_2_task_counts     = CbrainTask.group("group_id").count
    @group_id_2_user_counts     = User.joins(:groups).group("group_id").count.convert_keys!(&:to_i) # .joins make keys as string
    if @scope.custom[:button]
      @group_id_2_userfile_counts[nil] = Userfile.find_all_accessible_by_user(current_user, :access_requested => :read).count
      @group_id_2_task_counts[nil]     = current_user.available_tasks.count
    else
      @group_id_2_tool_counts          = Tool.group("group_id").count
      @group_id_2_data_provider_counts = DataProvider.group("group_id").count
      @group_id_2_bourreau_counts      = Bourreau.group("group_id").count
      @group_id_2_brain_portal_counts  = BrainPortal.group("group_id").count
    end

    scope_to_session(@scope)
    current_session.save_preferences

    respond_to do |format|
      format.js
      format.html # index.html.erb
      format.xml  { render :xml  => @groups }
      format.json { render :json => @groups.to_json(methods: :type) }
    end
  end

  def show #:nodoc:
    #@group = current_user.available_groups.find(params[:id])
    @group = Group.find(params[:id])
    raise ActiveRecord::RecordNotFound unless @group.can_be_accessed_by?(current_user)
    @users = current_user.available_users.where( "users.login <> 'admin'" ).order(:login)
  end

  def new  #:nodoc:
    @group = WorkGroup.new
    @users = current_user.available_users.where( "users.login <> 'admin'" ).order(:login)
    render :partial => "new"
  end

  # POST /groups
  # POST /groups.xml
  def create  #:nodoc:
    @group = WorkGroup.new(params[:group])
    @group.make_accessible!(:invisible) if current_user.has_role?(:admin_user)
    @group.attributes = params[:group]

    unless current_user.has_role? :admin_user
      @group.site = current_user.site
    end

    unless @group.user_ids.blank?
      @group.user_ids &= current_user.available_users.map(&:id)
    end

    @group.creator_id = current_user.id

    respond_to do |format|
      if @group.save
        @group.addlog_context(self,"Created by #{current_user.login}")
        flash[:notice] = 'Project was successfully created.'
        format.js   { redirect_to :action => :index, :format => :js}
        format.xml  { render :xml => @group, :status => :created, :location => @group }
      else
        @users = current_user.available_users.where( "users.login<>'admin'" ).order( :login )
        format.js   { render :partial  => 'shared/failed_create', :locals  => {:model_name  => 'group' } }
        format.xml  { render :xml => @group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /groups/1
  # PUT /groups/1.xml
  def update #:nodoc:
    @group = current_user.available_groups.where( :type => "WorkGroup" ).find(params[:id])

    unless @group.can_be_edited_by?(current_user)
       flash[:error] = "You don't have permission to edit this project."
       respond_to do |format|
        format.html { redirect_to :action => :show }
        format.xml  { head :forbidden }
       end
       return
    end

    original_user_ids = @group.user_ids

    params[:group] ||= {}

    unless current_user.has_role? :admin_user
      params[:group][:site_id] = current_user.site_id
    end

    unless params[:update_users].present?
      params[:group][:user_ids] = @group.user_ids.map(&:to_s)
    end

    params[:group][:user_ids] ||= []

    unless params[:group][:user_ids].blank?
      if current_user.has_role? :normal_user
        params[:group][:user_ids] &= @group.user_ids.map(&:to_s)
      else
        params[:group][:user_ids] &= current_user.visible_users.map{ |u| u.id.to_s  }
      end
    end

    @group.make_accessible!(:invisible) if current_user.has_role?(:admin_user)
    params[:group].delete :creator_id #creator_id is immutable

    @users = current_user.available_users.where( "users.login <> 'admin'" ).order(:login)
    respond_to do |format|
      if @group.update_attributes_with_logging(params[:group],current_user)
        @group.reload
        @group.addlog_object_list_updated("Users", User, original_user_ids, @group.user_ids, current_user, :login)
        flash[:notice] = 'Project was successfully updated.'
        format.html { redirect_to :action => "show" }
        format.xml  { head :ok }
      else
        @group.reload
        format.html { render :action => "show" }
        format.xml  { render :xml => @group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # Used in order to remove a user from a group.
  def unregister
    @group = current_user.available_groups.where( :type => "WorkGroup" ).find(params[:id])

    respond_to do |format|
      if current_user.id == @group.creator_id
        flash[:error] = "You cannot be unregistered from a project you created."
        format.html { redirect_to group_path(@group) }
        format.xml  { head :unprocessable_entity }
      else
        original_user_ids = @group.user_ids
        @group.user_ids   = @group.user_ids - [current_user.id]
        @group.addlog_object_list_updated("Users", User, original_user_ids, @group.user_ids, current_user, :login)

        flash[:notice] = "You have been unregistered from project #{@group.name}."
        format.html { redirect_to :action => "index" }
        format.xml  { head :ok }
      end
    end
  end

  # DELETE /groups/1
  # DELETE /groups/1.xml
  def destroy  #:nodoc:
    @group = current_user.available_groups.find(params[:id])
    @group.destroy

    respond_to do |format|
      format.html { redirect_to :action => :index }
      format.js   { redirect_to :action => :index, :format => :js}
      format.xml  { head :ok }
    end
  end

  def switch #:nodoc:
    redirect_controller = params[:redirect_controller] || :groups
    redirect_action     = params[:redirect_action]     || :index
    redirect_id         = params[:redirect_id]

    ['userfiles', 'tasks'].each do |name|
      scope = scope_from_session(name)
      scope.filters.reject! { |f| f.attribute.to_s == 'group_id' }
      scope_to_session(scope)
    end

    current_session[:persistent_userfiles].clear rescue nil

    redirect_path = { :controller => redirect_controller, :action => redirect_action }
    redirect_path[:id] = redirect_id unless redirect_id.blank?

    if params[:id].blank?
      current_session[:active_group_id] = nil
    elsif params[:id] == "all"
      current_session[:active_group_id] = "all"
    else
      @group = current_user.available_groups.find(params[:id])
      current_session[:active_group_id] = @group.id
    end

    redirect_to userfiles_path
  end

end
