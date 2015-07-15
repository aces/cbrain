
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

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  api_available :only => [ :index, :create, :show, :destroy , :update]

  before_filter :login_required,        :except => [:request_password, :send_password]
  before_filter :manager_role_required, :except => [:show, :edit, :update, :request_password, :send_password, :change_password]

  API_HIDDEN_ATTRIBUTES = [ :salt, :crypted_password ]

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

    # Turn the array ordered_real into the final paginated collection
    @users = @users.paginate(:page => @current_page, :per_page => @per_page)

    current_session.save_preferences_for_user(current_user, :users, :per_page)

    respond_to do |format|
      format.html # index.html.erb
      format.js
      format.xml  do
        @users.each { |u| u.hide_attributes(API_HIDDEN_ATTRIBUTES) }
        render :xml  => @users
      end
      format.json do
        @users.each { |u| u.hide_attributes(API_HIDDEN_ATTRIBUTES) }
        render :json => @users
      end
    end
  end

  # GET /user/1
  # GET /user/1.xml
  def show #:nodoc:
    @user = User.find(params[:id], :include => :groups)

    cb_error "You don't have permission to view this page.", :redirect  => start_page_path unless edit_permission?(@user)

    @default_data_provider  = DataProvider.find_by_id(@user.meta["pref_data_provider_id"])
    @default_bourreau       = Bourreau.find_by_id(@user.meta["pref_bourreau_id"])
    @log                    = @user.getlog()

    respond_to do |format|
      format.html # show.html.erb
      format.xml  do
        @user.hide_attributes(API_HIDDEN_ATTRIBUTES)
        render :xml  => @user
      end
      format.json do
        @user.hide_attributes(API_HIDDEN_ATTRIBUTES)
        render :json => @user
      end
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

    no_password_reset_needed = params[:no_password_reset_needed] == "1"

    if current_user.has_role? :site_manager
      if params[:user][:type] == 'SiteManager'
        params[:user][:type] = 'SiteManager'
      else
        params[:user][:type] = 'NormalUser'
      end
    end

    @user = User.new

    @user.make_all_accessible! if current_user.has_role?(:admin_user)
    if current_user.has_role?(:site_manager)
      @user.make_accessible!(:login, :type, :group_ids, :account_locked)
      @user.site = current_user.site
    end

    @user.attributes = params[:user]

    @user = @user.class_update

    @user.password_reset = no_password_reset_needed ? false : true

    if @user.save
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
        format.js   { redirect_to :action => :index, :format => :js }
        format.xml  { render :xml  => @user }
        format.json { render :json => @user }
      end
    else
      respond_to do |format|
        format.js   { render :partial  => 'shared/failed_create', :locals  => { :model_name  => 'user' } }
        format.xml  { render :xml  => @user.errors, :status => :unprocessable_entity }
        format.json { render :json => @user.errors, :status => :unprocessable_entity }
      end
    end
  end

  def change_password #:nodoc:
    @user = User.find(params[:id])
    cb_error "You don't have permission to view this page.", :redirect => start_page_path unless edit_permission?(@user)
  end

  # PUT /users/1
  # PUT /users/1.xml
  def update #:nodoc:
    @user = User.find(params[:id], :include => :groups)
    params[:user] ||= {}
    cb_error "You don't have permission to view this page.", :redirect => start_page_path unless edit_permission?(@user)

    if params[:user][:group_ids]
      system_group_scope = SystemGroup.scoped
      params[:user][:group_ids]  |= system_group_scope.joins(:users).where( "users.id" => @user.id ).raw_first_column("groups.id").map(&:to_s)
      unless current_user.has_role?(:admin_user)
        params[:user][:group_ids]  |= WorkGroup.where(invisible: true).raw_first_column("groups.id").map(&:to_s)
      end
    end

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

    # For logging
    original_group_ids = @user.group_ids

    @user.make_all_accessible! if current_user.has_role?(:admin_user)
    if current_user.has_role? :site_manager
      @user.make_accessible!(:group_ids, :type, :account_locked)
      if params[:user][:type] == 'SiteManager'
        params[:user][:type] = 'SiteManager'
      else
        params[:user][:type] = 'NormalUser'
      end
      @user.site = current_user.site
    end

    @user.attributes = params[:user]

    @user = @user.class_update

    respond_to do |format|
      if @user.save_with_logging(current_user, %w( full_name login email role city country account_locked ) )
        @user.reload
        @user.addlog_object_list_updated("Groups", Group, original_group_ids, @user.group_ids, current_user)
        add_meta_data_from_form(@user, [:pref_bourreau_id, :pref_data_provider_id])
        flash[:notice] = "User #{@user.login} was successfully updated."
        format.html { redirect_to :action => :show }
        format.xml { head :ok }
        format.json  { render :json => @user }
      else
        @user.reload
        format.html do
          if params[:user][:password]
            render action: "change_password"
          else
            render action: "show"
          end
        end
        format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
        format.json { render :json => @user.errors, :status => :unprocessable_entity }
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
      format.json { head :ok }
    end
  rescue ActiveRecord::DeleteRestrictionError => e
    flash[:error]  = "User not destroyed: #{e.message}"

    respond_to do |format|
      format.html { redirect_to :action => :index }
      format.js   { redirect_to :action => :index, :format => :js}
      format.xml  { head :conflict }
      format.json { head :conflict}
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
      if @user.account_locked?
        contact = RemoteResource.current_resource.support_email.presence || User.admin.email.presence || "the support staff"
        flash[:error] = "This account is locked, please write to #{contact} to get this account unlocked."
        respond_to do |format|
          format.html { redirect_to :action  => :request_password }
          format.xml  { render :nothing => true, :status  => 401 }
        end
        return
      end
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
