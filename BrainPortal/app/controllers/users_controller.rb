
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

#RESTful controller for the User resource.
class UsersController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__]

  api_available :only => [ :create, :show ]

  before_filter :login_required,        :except => [:request_password, :send_password]  
  before_filter :manager_role_required, :except => [:show, :edit, :update, :request_password, :send_password]  
  
  def index #:nodoc:
    @filter_params["sort_hash"]["order"] ||= 'users.full_name'

    sort_order = "#{@filter_params["sort_hash"]["order"]} #{@filter_params["sort_hash"]["dir"]}"
    
    @header_scope = current_user.available_users
    
    @filtered_scope = base_filtered_scope @header_scope.includes( [:groups, :site] ).order( sort_order )
    @users          = base_sorted_scope @filtered_scope

    # Precompute file and task counts.
    @users_file_counts=Userfile.where(:user_id => @users.map(&:id)).group(:user_id).count
    @users_task_counts=CbrainTask.real_tasks.where(:user_id => @users.map(&:id)).group(:user_id).count

    # For Pagination
    unless [:html, :js].include?(request.format.to_sym)
      @per_page = 999_999_999
    end
    
    @total_users  = @users.count

    # Turn the array ordered_real into the final paginated collection
    @users = @users.paginate(:page => @current_page, :per_page => @per_page)
    
    respond_to do |format|
      format.html # index.html.erb
      format.js
      format.xml  { render :xml => @users }
    end
  end
  
  # GET /user/1
  # GET /user/1.xml
  def show #:nodoc:
    @user = User.find(params[:id], :include => :groups)

    cb_error "You don't have permission to view this page.", :redirect  => home_path unless edit_permission?(@user)

    @default_data_provider  = DataProvider.find_by_id(@user.meta["pref_data_provider_id"])
    @default_bourreau       = Bourreau.find_by_id(@user.meta["pref_bourreau_id"]) 
    @log                    = @user.getlog()

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @user }
    end
  end

  def new #:nodoc:
    @user = User.new
    render :partial => "new"
  end

  def create #:nodoc:
    cookies.delete :auth_token
    # protects against session fixation attacks, wreaks havoc with 
    # request forgery protection.
    # uncomment at your own risk
    # reset_session
    params[:user] ||= {}

    # These attributes must be set explicitely
    login          = params[:user].delete :login
    type_param     = params[:user].delete :type
    group_ids      = params[:user].delete :group_ids
    site_id        = params[:user].delete :site_id
    account_locked = params[:user].delete :account_locked

    no_password_reset_needed = params[:no_password_reset_needed] == "1"
 
    if current_user.has_role? :admin_user
      type = type_param
    elsif current_user.has_role? :site_manager
      if type_param == 'SiteManager'
        type = 'SiteManager'
      else
        type = 'NormalUser'
      end
    end
    
    params[:user][:type] = type
 
    @user = User.sti_new(params[:user])

    if current_user.has_role? :admin_user
      @user.login          = login     if login
      @user.group_ids      = group_ids if group_ids
      @user.site_id        = site_id   if site_id
      @user.account_locked = (account_locked == "1")
    end

    if current_user.has_role? :site_manager
      @user.login          = login     if login
      @user.group_ids      = group_ids if group_ids
      @user.account_locked = (account_locked == "1")
      @user.site = current_user.site
    end

    @user.password_reset = no_password_reset_needed ? false : true
    @user.save
    
    if @user.errors.empty?
      flash[:notice] = "User successfully created."
      current_user.addlog_context(self,"Created account for user '#{@user.login}'")
      @user.addlog_context(self,"Account created by '#{current_user.login}'")
      if @user.email.blank? || @user.email =~ /example/i || @user.email !~ /@/
        flash[:notice] += "Since this user has no proper E-Mail address, no welcome E-Mail was sent."
      else
        flash[:notice] += "\nA welcome E-Mail is being sent to '#{@user.email}'."
        CbrainMailer.registration_confirmation(@user,params[:user][:password],no_password_reset_needed).deliver rescue nil
      end
      respond_to do |format|
        format.js  { redirect_to :action => :index, :format => :js }
        format.xml { render :xml => @user }
      end
    else
      respond_to do |format|                                                                  
        format.js  { render :partial  => 'shared/failed_create', :locals  => { :model_name  => 'user' } }
        format.xml { render :xml => @user.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /users/1
  # PUT /users/1.xml
  def update #:nodoc:
    @user = User.find(params[:id], :include => :groups)
    params[:user] ||= {}
    cb_error "You don't have permission to view this page.", :redirect => home_path unless edit_permission?(@user)
  
    params[:user][:group_ids] ||= WorkGroup.joins(  :users).where( "users.id" => @user.id ).raw_first_column("groups.id").map &:to_s
    params[:user][:group_ids]  |= SystemGroup.joins(:users).where( "users.id" => @user.id ).raw_first_column("groups.id").map &:to_s
  
    if params[:user][:password].present?
      if current_user.id == @user.id
        @user.password_reset = false
      else
        @user.password_reset = params[:force_password_reset] != '0'
      end
    else
      params[:user].delete(:password)
      params[:user].delete(:password_confirmation)
    end
  
    if params[:user].has_key?(:time_zone) && (params[:user][:time_zone].blank? || !ActiveSupport::TimeZone[params[:user][:time_zone]])
      params[:user][:time_zone] = nil # change "" to nil
    end
  
    # These attributes must be set explicitely
    type = params[:user].delete :type
    group_ids = params[:user].delete :group_ids
    site_id = params[:user].delete :site_id
    account_locked = params[:user].delete :account_locked
  
    # For logging
    original_group_ids = @user.group_ids
  
    # Update everything else!
    @user.attributes = params[:user]
  
    if current_user.has_role? :admin_user
      @user.type = type if type
      @user.group_ids = group_ids if group_ids
      @user.site_id = site_id if site_id
      @user.account_locked = (account_locked == "1")
      @user.destroy_user_sessions if @user.account_locked
    end
  
    if current_user.has_role? :site_manager
      @user.group_ids = group_ids if group_ids
      if type
        if type == 'SiteManager'
          @user.type = 'SiteManager'
        else
          @user.type = 'NormalUser'
        end
      end
      @user.site = current_user.site
    end 
    @user = @user.class_update

    respond_to do |format|
      if @user.save_with_logging(current_user, %w( full_name login email role city country account_locked ) )
        @user.reload
        @user.addlog_object_list_updated("Groups", Group, original_group_ids, @user.group_ids, current_user)
        add_meta_data_from_form(@user, [:pref_bourreau_id, :pref_data_provider_id])
        flash[:notice] = "User #{@user.login} was successfully updated."
        format.html { redirect_to :action => :show }
        format.xml { head :ok }
      else
        @user.reload
        format.html { render :action => "show" }
        format.xml { render :xml => @user.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy #:nodoc:
    if current_user.has_role? :admin_user
      @user = User.find(params[:id])
    elsif current_user.has_role? :site_manager
      @user = current_user.site.users.find(params[:id])
    end
    
    @user.destroy 
    
    flash[:notice] = "User '#{@user.login}' destroyed" 

    respond_to do |format|
      format.html { redirect_to :action => :index }
      format.js   { redirect_to :action => :index, :format => :js}
      format.xml  { head :ok }
    end
  rescue ActiveRecord::DeleteRestrictionError => e
    flash[:error]  = "User not destroyed: #{e.message}"
    
    respond_to do |format|
      format.html { redirect_to :action => :index }
      format.js   { redirect_to :action => :index, :format => :js}
      format.xml  { head :conflict }
    end
  end

  def switch #:nodoc:
    if current_user.has_role? :admin_user
      @user = User.find(params[:id])
    elsif current_user.has_role? :site_manager
      @user = current_user.site.users.find(params[:id])
    end

    myportal = RemoteResource.current_resource
    myportal.addlog("Admin user '#{current_user.login}' switching to user '#{@user.login}'")
    current_user.addlog("Switching to user '#{@user.login}'")
    @user.addlog("Switched from user '#{current_user.login}'")
    current_session.clear_data!
    self.current_user = @user
    current_session[:user_id] = @user.id
    
    redirect_to start_page_path
  end
  
  def request_password #:nodoc:
  end
  
  def send_password #:nodoc:
    @user = User.where( :login  => params[:login], :email  => params[:email] ).first

    if @user
      @user.password_reset = true
      @user.set_random_password
      if @user.save
        CbrainMailer.forgotten_password(@user).deliver
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
