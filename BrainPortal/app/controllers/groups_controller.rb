
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

  Revision_info=CbrainFileRevision[__FILE__]

  before_filter :login_required

  # GET /groups
  # GET /groups.xml
  def index  #:nodoc:
    @filter_params["sort_hash"]["order"] ||= "groups.name"
    @filter_params["button_view"] ||= "on"
    @header_scope = current_user.available_groups
    scope = base_filtered_scope @header_scope.includes(:site)
    @total_entries = scope.count
    
    # For Pagination
    @per_page = 50 unless @filter_params["per_page"]
    offset = (@current_page - 1) * @per_page
     
    if @filter_params["button_view"] == "on"
      pagination_list = scope.limit(@per_page).offset(offset).where("groups.type = 'WorkGroup'").all
      num_workgroups  = pagination_list.size
      num_missing     = @per_page - num_workgroups
      
      if num_missing > 0
        total_workgroups = scope.where("groups.type = 'WorkGroup'").count
        sys_offset = [offset - total_workgroups, 0].max
        pagination_list += scope.limit(num_missing).offset(sys_offset).where("groups.type <> 'WorkGroup'").all
      end
      num_missing = @per_page - pagination_list.size
      if num_missing > 0 
        pagination_list << "ALL"
      end 
      @total_entries += 1
    else
      pagination_list  = scope.limit(@per_page).offset(offset)
    end
    
    @groups = WillPaginate::Collection.create(@current_page, @per_page) do |pager|
      pager.replace(pagination_list)
      pager.total_entries = @total_entries
      pager
    end
    
    @group_id_2_userfile_counts      = Userfile.group("group_id").count
    @group_id_2_task_counts          = CbrainTask.group("group_id").count
    if @filter_params["button_view"] == "on"
      @group_id_2_userfile_counts[nil] = Userfile.find_all_accessible_by_user(current_user, :access_requested => :read).count
      @group_id_2_task_counts[nil]     = current_user.available_tasks.count
    else
      @group_id_2_user_counts          = User.joins(:groups).group("group_id").count.convert_keys!(&:to_i) # .joins make keys as string
      @group_id_2_tool_counts          = Tool.group("group_id").count
      @group_id_2_data_provider_counts = DataProvider.group("group_id").count
      @group_id_2_bourreau_counts      = Bourreau.group("group_id").count
      @group_id_2_brain_portal_counts  = BrainPortal.group("group_id").count
    end

    respond_to do |format|
      format.js
      format.html # index.html.erb
      format.xml  { render :xml => @groups }
    end
  end
  
  def show #:nodoc:
    @group = current_user.available_groups.find(params[:id])
    @users = current_user.available_users.where( "users.login <> 'admin'" ).order(:login)
  end

  def new  #:nodoc:
    @group = WorkGroup.new
    @users = current_user.available_users( "users.login <> 'admin'" ).order(:login)
    render :partial => "new"
  end

  # POST /groups
  # POST /groups.xml
  def create  #:nodoc:

    if current_user.has_role?(:admin_user) && params[:invisible_group] == "1"
      @group = InvisibleGroup.new(params[:group])
    else
      @group = WorkGroup.new(params[:group])
    end
    
    unless current_user.has_role? :admin_user
      @group.site = current_user.site
    end

    unless @group.user_ids.blank?
      @group.user_ids &= current_user.available_users.map(&:id)
    end
   
    @group.creator_id = current_user.id

    respond_to do |format|
      if @group.save
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
    if current_user.has_role? :admin_user
      @group = Group.where( :type => [ "WorkGroup", "InvisibleGroup" ] ).find(params[:id])
    else
      @group = WorkGroup.find(params[:id])
    end

    unless params[:commit] == "Update Users"
      params[:group][:user_ids] = @group.user_ids.map(&:to_s)
    end

    params[:group][:user_ids] ||= []

    if current_user.has_role?(:admin_user) && params[:invisible_group] == "1"
      @group.type = 'InvisibleGroup'
    else
      @group.type = 'WorkGroup'
    end
    
    unless current_user.has_role? :admin_user
      params[:group][:site_id] = current_user.site_id
    end

    unless params[:group][:user_ids].blank?
      params[:group][:user_ids] &= current_user.available_users.map{ |u| u.id.to_s  }
    end

    params[:group].delete :creator_id #creator_id is immutable

    @users = current_user.available_users.where( "users.login <> 'admin'" ).order(:login)
    respond_to do |format|
      if @group.update_attributes(params[:group])
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
  
  def switch_panel #:nodoc:
    @all_projects = current_user.available_groups.partition {|p| p.class.to_s == "WorkGroup" }.map{ |set| set.sort_by(&:name)  }.flatten
    @redirect_controller = params[:redirect_controller] || :groups
    render :partial => 'switch_panel'
  end
  
  def switch #:nodoc:
    redirect_controller = params[:redirect_controller] || :groups
    redirect_action     = params[:redirect_action] || :index
    redirect_id         = params[:redirect_id]

    current_session.param_chain("userfiles", "filter_hash").delete("group_id")
    current_session.param_chain("tasks"    , "filter_hash").delete("group_id")

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
