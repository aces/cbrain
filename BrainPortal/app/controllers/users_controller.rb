
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
  before_filter :admin_role_required, :except => [:show, :edit, :update]  
  
  def index #:nodoc:
    @users = User.find(:all, :include => [:groups, :userfiles])
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @users }
    end
  end
  
  # GET /user/1
  # GET /user/1.xml
  def show #:nodoc:
    @user = User.find(params[:id], :include => [:groups, :user_preference])
    @default_data_provider  = @user.user_preference.data_provider.name rescue "(Unset)"
    @default_bourreau       = @user.user_preference.bourreau.name      rescue "(Unset)"

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @userfile }
    end
  end

  # render new.rhtml
  def new #:nodoc:
    @groups = WorkGroup.find(:all)
  end
  
  def edit #:nodoc:
    @user = User.find(params[:id], :include => :groups)
    if !edit_permission? @user
      access_error(401)
      return
    end
    @groups = WorkGroup.find(:all)
  end 

  def create #:nodoc:
    cookies.delete :auth_token
    # protects against session fixation attacks, wreaks havoc with 
    # request forgery protection.
    # uncomment at your own risk
    # reset_session
    
    @user = User.new(params[:user])
        
    newGroup = SystemGroup.new(:name => @user.login)
    newGroup.save
    everyoneGroup = SystemGroup.find_by_name("everyone")
    group_ids = @user.group_ids
    group_ids << newGroup.id
    group_ids << everyoneGroup.id
    @user.group_ids = group_ids

    @user.save
    
    if @user.errors.empty?
      redirect_to(users_url)
      flash[:notice] = "User successfully created."
    else
      @groups = WorkGroup.find(:all)
      render :action => 'new'
    end
  end

  # PUT /users/1
  # PUT /users/1.xml
  def update #:nodoc:
    @user = User.find(params[:id], :include => :groups)
    params[:user][:group_ids] ||= []
    respond_to do |format|
      if @user.update_attributes(params[:user])
        flash[:notice] = "User #{@user.login} was successfully updated."
        format.html { redirect_to @user }
        format.xml  { head :ok }
      else
        @groups = WorkGroup.find(:all)
        format.html { render :action => "edit" }
        format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy #:nodoc:
    @user = User.find(params[:id])
    
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
