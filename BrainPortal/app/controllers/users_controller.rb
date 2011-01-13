
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

  before_filter :login_required,        :except => [:request_password, :send_password]  
  before_filter :manager_role_required, :except => [:show, :edit, :update, :request_password, :send_password]  
  
  def index #:nodoc:
    @filter_params["sort"]["order"] ||= 'users.full_name'
    @filter_params["sort"]["dir"]   ||= ''
    
    sort_order = "#{@filter_params["sort"]["order"]} #{@filter_params["sort"]["dir"]}"
    
    @users = current_user.available_users(:all, :include => [:groups, :site], :order  => sort_order )
    
    #For the 'new' panel
    @user = User.new
    if current_user.has_role? :admin
      @groups = WorkGroup.find(:all)
    elsif current_user.has_role? :site_manager
      @groups = current_user.site.groups.find(:all, :conditions  => {:type  => "WorkGroup"})
    end
    @groups = @groups.sort { |a,b| a.name <=> b.name }
    
    respond_to do |format|
      format.html # index.html.erb
      format.js
      format.xml  { render :xml => @users }
    end
  end
  
  # GET /user/1
  # GET /user/1.xml
  def show #:nodoc:
    @user = User.find(params[:id], :include => [:groups, :user_preference])
    
    cb_error "You don't have permission to view this page.", :redirect  => home_path unless edit_permission?(@user)

    if current_user.has_role? :admin
      @groups = WorkGroup.find(:all)  # used for 'edit' form
    elsif current_user.has_role? :site_manager
      @groups = current_user.site.groups.find(:all, :conditions  => {:type  => "WorkGroup"})  # used for 'new' form
    else
      @groups = [] # defensive; not used normally for ordinary users
    end
    
    @default_data_provider  = @user.user_preference.data_provider rescue nil
    @default_bourreau       = @user.user_preference.bourreau      rescue nil
    @log                    = @user.getlog()

    stats = ApplicationController.helpers.gather_filetype_statistics(
              :users     => @user.available_users,
              :providers => DataProvider.all
            )
    @user_fileclass_count = stats[:user_fileclass_count]
    @fileclasses_totcount = stats[:fileclasses_totcount]
    @user_totcount        = stats[:user_totcount]

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @userfile }
    end
  end

  def create #:nodoc:
    cookies.delete :auth_token
    # protects against session fixation attacks, wreaks havoc with 
    # request forgery protection.
    # uncomment at your own risk
    # reset_session
    
    login     = params[:user].delete :login
    role      = params[:user].delete :role
    group_ids = params[:user].delete :group_ids
    site_id   = params[:user].delete :site_id
    
    @user = User.new(params[:user])
    
    if current_user.has_role? :admin
      @user.login     = login     if login
      @user.role      = role      if role
      @user.group_ids = group_ids if group_ids
      @user.site_id   = site_id   if site_id
    end
    
    if current_user.has_role? :site_manager
      @user.login     = login     if login
      @user.group_ids = group_ids if group_ids
      if role 
        if role == 'site_manager'
          @user.role = 'site_manager'
        else
          @user.role = 'user'
        end
      end
      @user.site = current_user.site
    end

    @user.password_reset = true
    @user.save
    
    if @user.errors.empty?
      flash[:notice] = "User successfully created."
      current_user.addlog_context(self,"Created account for user '#{@user.login}'")
      @user.addlog_context(self,"Account created by '#{current_user.login}'")
      if @user.email.blank? || @user.email =~ /example/i || @user.email !~ /@/
        flash[:notice] += "Since this user has no proper E-Mail address, no welcome E-Mail was sent."
      else
        flash[:notice] += "\nA welcome E-Mail is being sent to '#{@user.email}'."
        CbrainMailer.deliver_registration_confirmation(@user,params[:user][:password]) rescue nil
      end
    end
    
    if current_user.has_role? :admin
      @groups = WorkGroup.find(:all)
    elsif current_user.has_role? :site_manager
      @groups = current_user.site.groups.find(:all, :conditions  => {:type  => "WorkGroup"})
    end
    
    respond_to do |format|
      format.js {render :partial  => 'shared/create', :locals  => {:model_name  => 'user' }}
    end
  end

  # PUT /users/1
  # PUT /users/1.xml
  def update #:nodoc:
    @user = User.find(params[:id], :include => :groups)
    
    cb_error "You don't have permission to view this page.", :redirect  => home_path unless edit_permission?(@user)
    
    params[:user][:group_ids] ||=   WorkGroup.all(:joins  =>  :users, :conditions => {"users.id" => @user.id}).map(&:id)
    params[:user][:group_ids]  |= SystemGroup.all(:joins  =>  :users, :conditions => {"users.id" => @user.id}).map(&:id)
    
    if params[:user][:password]
      params[:user].delete :password_reset
      @user.password_reset = current_user.id == @user.id ? false : true
    end

    if params[:user][:time_zone].blank? || !ActiveSupport::TimeZone[params[:user][:time_zone]]
      params[:user][:time_zone] = nil # change "" to nil
    end
    
    role      = params[:user].delete :role
    group_ids = params[:user].delete :group_ids
    site_id   = params[:user].delete :site_id
    
    @user.attributes = params[:user]
    
    if current_user.has_role? :admin
      @user.role      = role      if role
      @user.group_ids = group_ids if group_ids
      @user.site_id   = site_id   if site_id
    end
    
    if current_user.has_role? :site_manager
      @user.group_ids = group_ids if group_ids
      if role 
        if role == 'site_manager'
          @user.role = 'site_manager'
        else
          @user.role = 'user'
        end
      end
      @user.site = current_user.site
    end
      
    respond_to do |format|
      if @user.save
        flash[:notice] = "User #{@user.login} was successfully updated."
        format.html { redirect_to @user }
        format.xml  { head :ok }
      else
        flash.now[:error] ||= ""
        @user.errors.each do |field, message|
          flash.now[:error] += "#{field} #{message}.\n".humanize
        end
        if current_user.has_role? :admin
          @groups = WorkGroup.find(:all)
        elsif current_user.has_role? :site_manager
          @groups = WorkGroup.find(:all, :conditions  => {:site_id  => current_user.site_id})
        end
        format.html { render :action => "show" }
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
    
    @destroyed = false
        
    @user.destroy
    @destroyed = true
    respond_to do |format|
      format.js {render :partial  => 'shared/destroy', :locals  => {:model_name  => 'user' }}
      format.xml  { head :ok }
    end
  end

  def switch #:nodoc:
    if current_user.has_role? :admin
      @user = User.find(params[:id])
    elsif current_user.has_role? :site_manager
      @user = current_user.site.users.find(params[:id])
    end

    myportal = RemoteResource.current_resource
    myportal.addlog("Admin user '#{current_user.login}' switching to user '#{@user.login}'")
    current_user.addlog("Switching to user '#{@user.login}'")
    @user.addlog("Switched from user '#{current_user.login}'")

    current_session.clear_data!
    current_user = @user
    current_session[:user_id] = @user.id
    
    redirect_to home_path
  end
  
  def request_password #:nodoc:
  end
  
  def send_password #:nodoc:
    @user = User.find(:first, :conditions  => {:login  => params[:login], :email  => params[:email]})
    
    if @user
      @user.password_reset = true
      @user.set_random_password
      if @user.save
        CbrainMailer.deliver_forgotten_password(@user)
        flash[:notice] = "#{@user.full_name}, your new password has been sent to you via e-mail. You should receive it shortly."
        flash[:notice] += "\nIf you do not receive your new password within 24hrs, please contact your admin."
        redirect_to login_path
      else
        flash[:error] = "Unable to reset password.\nPlease contact your admin."
        redirect_to :action  => :request_password
      end
    else
      flash[:error] = "Unable to find user with login #{params[:login]} and email #{params[:email]}.\nPlease contact your admin."
      redirect_to :action  => :request_password
    end
  end

end
