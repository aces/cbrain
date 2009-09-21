
#
# CBRAIN Project
#
# Users controller for the BrainPortal interface
#
# Original author: restful_authentication plugin
# Modified by: Tarek Sherif
#
# $Id$
#

#RESTful controller for the User resource.
class UsersController < ApplicationController

  Revision_info="$Id$"

  before_filter :login_required
  before_filter :manager_role_required, :except => [:show, :edit, :update]  
  
  def index #:nodoc:
    if current_user.has_role? :admin
      @users = User.find(:all, :include => :groups)
    elsif current_user.has_role? :site_manager
      @users = current_user.site.users.find(:all, :include => :groups)
    end
    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @users }
    end
  end
  
  # GET /user/1
  # GET /user/1.xml
  def show #:nodoc:
    @user = User.find(params[:id], :include => [:groups, :user_preference])
    if current_user.has_role? :admin
      @groups = WorkGroup.find(:all)
    elsif current_user.has_role? :site_manager
      @groups = current_user.site.groups.find(:all, :conditions  => {:type  => "WorkGroup"})
    end
    
    @default_data_provider  = @user.user_preference.data_provider.name rescue "(Unset)"
    @default_bourreau       = @user.user_preference.bourreau.name      rescue "(Unset)"
    @log                    = @user.getlog()

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @userfile }
    end
  end

  # render new.rhtml
  def new #:nodoc:
    @user = User.new(:site_id => current_user.site_id)
    if current_user.has_role? :admin
      @groups = WorkGroup.find(:all)
    elsif current_user.has_role? :site_manager
      @groups = current_user.site.groups.find(:all, :conditions  => {:type  => "WorkGroup"})
    end
  end
  
  def edit #:nodoc:
    @user = User.find(params[:id], :include => :groups)
    if current_user.has_role? :admin
      @groups = WorkGroup.find(:all)
    elsif current_user.has_role? :site_manager
      @groups = current_user.site.groups.find(:all, :conditions  => {:type  => "WorkGroup"})
    end

    @log = @user.getlog()
    
    if !edit_permission? @user
      access_error(401)
      return
    end
  end 

  def create #:nodoc:
    cookies.delete :auth_token
    # protects against session fixation attacks, wreaks havoc with 
    # request forgery protection.
    # uncomment at your own risk
    # reset_session
    
    @user = User.new(params[:user])
        
    if current_user.has_role? :site_manager
      @user.site = current_user.site
    end

    @user.save
    
    if @user.errors.empty?
      redirect_to(users_url)
      flash[:notice] = "User successfully created."
      current_user.addlog_context(self,"Created account for user '#{@user.login}'")
      @user.addlog_context(self,"Account created by '#{current_user.login}'")
    else
      if current_user.has_role? :admin
        @groups = WorkGroup.find(:all)
      elsif current_user.has_role? :site_manager
        @groups = current_user.site.groups.find(:all, :conditions  => {:type  => "WorkGroup"})
      end      
      render :action => 'new'
    end
  end

  # PUT /users/1
  # PUT /users/1.xml
  def update #:nodoc:
    @user = User.find(params[:id], :include => :groups)
    params[:user][:group_ids] ||= []
    params[:user][:group_ids] |= @user.groups.find(:all, :conditions  => {:type  => "SystemGroup"} )  
      
    respond_to do |format|
      if @user.update_attributes(params[:user])
        flash[:notice] = "User #{@user.login} was successfully updated."
        format.html { redirect_to @user }
        format.xml  { head :ok }
      else
        if current_user.has_role? :admin
          @groups = WorkGroup.find(:all)
        elsif current_user.has_role? :site_manager
          @groups = current_user.site.groups.find(:all, :conditions  => {:type  => "WorkGroup"})
        end
        format.html { render :action => "edit" }
        format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy #:nodoc:
    if current_user.has_role? :admin
      @user = User.find(params[:id])
    elsif current_user.has_role? :site_manager
      @user = current_user.site.users.find(params[:id])
    end
        
    begin      
      @user.destroy
      respond_to do |format|
        format.html { redirect_to(users_url) }
        format.xml  { head :ok }
      end
    rescue => e
      flash[:error] = e.message
      respond_to do |format|
        format.html { redirect_to(users_url) }
        format.xml  { render :xml => @user, :status => :unprocessable_entity }
      end
    end
  end
end
