
#
# CBRAIN Project
#
# Groups controller for the BrainPortal interface
#
# Original author: Tarek Sherif
#
# $Id$
#

class GroupsController < ApplicationController

  Revision_info="$Id$"

  before_filter :login_required, :admin_role_required
  # GET /groups
  # GET /groups.xml
  def index
    @groups = Group.find(:all, :include => [:users, :institution, :userfiles])

    #@groups = Group.find(:all, :include => [:users])
     respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @groups }
    end
  end

  # GET /groups/1
  # GET /groups/1.xml
  def show
    #@group = Group.find(params[:id], :include => [:users, :manager])
    @group = Group.find(params[:id], :include => [:users])
    

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @group }
    end
  end

  # GET /groups/new
  # GET /groups/new.xml
  def new
    @group = Group.new
    @institution_names = Institution.find(:all).collect(&:name)

    _add_admin_to_group(@group)

   # @manager_names = User.find(:all).select{|u| (u.role == 'admin' || u.role == 'manager') && u.login != 'admin'}.collect(&:full_name)
   #@manager_names = User.find(:all).select{|u| (u.role == 'admin' || u.role == 'manager') && u.login != 'admin'}.collect(&:full_name)
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @group }
    end
  end

  # GET /groups/1/edit
  def edit
    @group = Group.find(params[:id])

    _add_admin_to_group(@group)

   # @institution_names = Institution.find(:all).collect(&:name)
  #  @manager_names = User.find(:all).select{|u| (u.role == 'admin' || u.role == 'manager') && u.login != 'admin'}.collect(&:full_name)
  end

  # POST /groups
  # POST /groups.xml
  def create
    @group = Group.new(params[:group])

    _add_admin_to_group(@group)

    respond_to do |format|
      if @group.save
        flash[:notice] = 'Group was successfully created.'
        format.html { redirect_to groups_path }
        format.xml  { render :xml => @group, :status => :created, :location => @group }
      else
        @institution_names = Institution.find(:all).map{|i| i.name}
        format.html { render :action => "new" }
        format.xml  { render :xml => @group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /groups/1
  # PUT /groups/1.xml
  def update
    @group = Group.find(params[:id], :include => :institution)
    params[:group][:user_ids] ||= []
    params[:group][:institution_id] ||= []
    
    _add_admin_to_group(@group)

    respond_to do |format|
      if @group.update_attributes(params[:group])
        flash[:notice] = 'Group was successfully updated.'
        format.html { redirect_to groups_path }
        format.xml  { head :ok }
      else
         @institution_names = Institution.find(:all).map{|i| i.name}
        format.html { render :action => "edit" }
        format.xml  { render :xml => @group.errors, :status => :unprocessable_entity }
      end
    end
  end

 
  # DELETE /groups/1
  # DELETE /groups/1.xml
  def destroy
    @group = Group.find(params[:id])
    @group.destroy

    respond_to do |format|
      format.html { redirect_to(groups_url) }
      format.xml  { head :ok }
    end
  end

  private
  
  # Makes sure all groups contain the 'admin' user
  def _add_admin_to_group(group) #:nodoc:
    user_ids = group.user_ids
    admin_id = User.find_by_login("admin").id
    user_ids << admin_id unless user_ids.include?(admin_id)
    group.user_ids = user_ids
  end

end
