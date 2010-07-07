
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

  Revision_info="$Id$"

  before_filter :login_required, :manager_role_required
  # GET /groups
  # GET /groups.xml
  def index  #:nodoc:    
    if current_user.has_role? :admin
      @system_groups = SystemGroup.find(:all, :include => [:users, :site], :order  => "groups.type")
      @work_groups = WorkGroup.find(:all, :include => [:users, :site], :order  => "groups.type")
    else
      @system_groups = current_user.site.groups.find(:all, :conditions  => {:type  => ["SystemGroup", "UserGroup", "SiteGroup"]}, :include => [:users], :order  => "groups.type")
      @work_groups = current_user.site.groups.find(:all, :conditions  => {:type  => "WorkGroup"}, :include => [:users], :order  => "groups.type")
    end
    
    #For new panel
    @group = WorkGroup.new
    if current_user.has_role? :admin
      @users = User.all.reject{|u| u.login == 'admin'}
    else
      @users = current_user.site.users.all.reject{|u| u.login == 'admin'}
    end

     respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @groups }
    end
  end

  # GET /groups/1/edit
  def edit  #:nodoc:
    if current_user.has_role? :admin
      @group = WorkGroup.find(params[:id])
      @users = User.all.reject{|u| u.login == 'admin'}
    else
      @group = current_user.site.groups.find(params[:id], :conditions  => {:type  => "WorkGroup"})
      @users = current_user.site.users.all.reject{|u| u.login == 'admin'}
    end
  end

  # POST /groups
  # POST /groups.xml
  def create  #:nodoc:
    @group = WorkGroup.new(params[:group])
    
    if current_user.has_role? :site_manager
      @group.site = current_user.site
    end

    if current_user.has_role? :admin
      @users = User.all.reject{|u| u.login == 'admin'}
    else
      @users = current_user.site.users.all.reject{|u| u.login == 'admin'}
    end

    respond_to do |format|
      if @group.save
        flash[:notice] = 'Group was successfully created.'
        format.js {render :partial  => 'shared/create', :locals  => {:model_name  => 'group' }}
        format.xml  { render :xml => @group, :status => :created, :location => @group }
      else
        format.js {render :partial  => 'shared/create', :locals  => {:model_name  => 'group' }}
        format.xml  { render :xml => @group.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /groups/1
  # PUT /groups/1.xml
  def update #:nodoc:
    @group = WorkGroup.find(params[:id])
    params[:work_group][:user_ids] ||= []

    respond_to do |format|
      if @group.update_attributes(params[:work_group])
        flash[:notice] = 'Group was successfully updated.'
        format.html { redirect_to groups_path }
        format.xml  { head :ok }
      else
        if current_user.has_role? :admin
          @users = User.all.reject{|u| u.login == 'admin'}
        else
          @users = current_user.site.users.all.reject{|u| u.login == 'admin'}
        end
        format.html { render :action => "edit" }
        format.xml  { render :xml => @group.errors, :status => :unprocessable_entity }
      end
    end
  end

 
  # DELETE /groups/1
  # DELETE /groups/1.xml
  def destroy  #:nodoc:
    if current_user.has_role? :admin
      @group = WorkGroup.find(params[:id])
    else
      @group = current_user.site.groups.find(params[:id], :conditions  => {:type  => "WorkGroup"})
    end
    @destroyed = @group.destroy

    respond_to do |format|
      format.js
      format.xml  { head :ok }
    end
  end
  
end
