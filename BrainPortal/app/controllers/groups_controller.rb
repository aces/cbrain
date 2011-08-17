
#
# CBRAIN Project
#
# Groups controller for the BrainPortal interface
#
# Original author: Tarek Sherif
#
# $Id$
#

#RESTful controller for the Group resource.
class GroupsController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__]

  before_filter :login_required

  # GET /groups
  # GET /groups.xml
  def index  #:nodoc:    
    @system_groups = base_filtered_scope current_user.available_groups(
      :type => (["SystemGroup"] | SystemGroup.descendants.map(&:name))
    ).includes(:site).order("groups.type, groups.name")
    @work_groups = base_filtered_scope current_user.available_groups(
      :type => (["WorkGroup"] | WorkGroup.descendants.map(&:name))
    ).includes(:site).order("groups.type, groups.name")
    
    #For new panel
    @group = WorkGroup.new
    @users = current_user.available_users( "users.login <> 'admin'" ).order(:login)

    common_form_elements()

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @groups }
    end
  end
  
  def show #:nodoc:
    @group = current_user.available_groups.find(params[:id])
  end

  # GET /groups/1/edit
  def edit  #:nodoc:
    if current_user.has_role? :admin
      @group = current_user.available_groups.where( :type => [ "WorkGroup", "InvisibleGroup" ] ).find(params[:id])
    else
      @group = current_user.available_groups.where( :type => "WorkGroup" ).find(params[:id])
    end
    @users = current_user.available_users.where( "users.login <> 'admin'" ).order(:login)
  end

  # POST /groups
  # POST /groups.xml
  def create  #:nodoc:

    if current_user.has_role?(:admin) && params[:invisible_group] == "1"
      @group = InvisibleGroup.new(params[:group])
    else
      @group = WorkGroup.new(params[:group])
    end
    
    unless current_user.has_role? :admin
      @group.site = current_user.site
    end

    respond_to do |format|
      if @group.save
        flash[:notice] = 'Project was successfully created.'
        common_form_elements()
        format.js
        format.xml  { render :xml => @group, :status => :created, :location => @group }
      else
        @users = current_user.available_users.where( "users.login<>'admin'" ).order( :login )
        format.js
        format.xml  { render :xml => @group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /groups/1
  # PUT /groups/1.xml
  def update #:nodoc:
    if current_user.has_role? :admin
      @group = Group.where( :type => [ "WorkGroup", "InvisibleGroup" ] ).find(params[:id])
    else
      @group = WorkGroup.find(params[:id])
    end

    params[:group][:user_ids] ||= []

    if current_user.has_role?(:admin) && params[:invisible_group] == "1"
      @group.type = 'InvisibleGroup'
    else
      @group.type = 'WorkGroup'
    end

    respond_to do |format|
      if @group.update_attributes(params[:group])
        flash[:notice] = 'Project was successfully updated.'
        format.html { redirect_to groups_path }
        format.xml  { head :ok }
      else
        @users = current_user.available_users.where( "users.login <> 'admin'" ).order(:login).reject{|u| u.login == 'admin'}
        format.html { render :action => "edit" }
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
      format.js   {render :partial  => 'shared/destroy', :locals  => {:model_name  => 'group' }}
      format.xml  { head :ok }
    end
  end
  
  def switch #:nodoc:
    redirect_controller = params[:redirect_controller] || :groups
    redirect_action = params[:redirect_action] || :index
    redirect_id = params[:redirect_id]
    
    if params[:id] == "off"
      current_session[:active_group_id] = nil
    else
      @group = current_user.available_groups.find(params[:id])
      current_session[:active_group_id] = @group.id
    end
    
    redirect_to :controller  => redirect_controller, :action  => redirect_action, :id  => redirect_id
  end

  private

  def common_form_elements
    @group_id_2_user_counts = {}
    User.joins(:groups).select( "group_id, count(group_id) as total" ).group("group_id").each do |user|
      @group_id_2_user_counts[user.group_id.to_i] = user.total
    end

    @group_id_2_userfile_counts = {}
    Userfile.select( "group_id, count(group_id) as total" ).group("group_id").each do |userfile|
      @group_id_2_userfile_counts[userfile.group_id] = userfile.total
    end

    @group_id_2_task_counts = {}
    CbrainTask.select( "group_id, count(group_id) as total" ).group("group_id").each do |task|
      @group_id_2_task_counts[task.group_id] = task.total
    end

    @group_id_2_tool_counts = {}
    Tool.select( "group_id, count(group_id) as total" ).group("group_id").each do |tool|
      @group_id_2_tool_counts[tool.group_id] = tool.total
    end

    @group_id_2_tag_counts = {}
    Tag.select( "group_id, count(group_id) as total" ).group("group_id").each do |tag|
      @group_id_2_tag_counts[tag.group_id] = tag.total
    end

    @group_id_2_data_provider_counts = {}
    DataProvider.select( "group_id, count(group_id) as total" ).group("group_id").each do |data_provider|
      @group_id_2_data_provider_counts[data_provider.group_id] = data_provider.total
    end

    @group_id_2_remote_resource_counts = {}
    RemoteResource.select( "group_id, count(group_id) as total" ).group("group_id").each do |remote_resource|
      @group_id_2_remote_resource_counts[remote_resource.group_id] = remote_resource.total
    end
    
  end

end
