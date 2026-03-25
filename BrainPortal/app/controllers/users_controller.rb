
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

require 'ipaddr'

#RESTful controller for the User resource.
class UsersController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include GlobusHelpers

  api_available :only => [ :index, :create, :show, :destroy, :update, :create_user_session, :push_keys, :new_token, :new_token_from_jwt ]

  before_action :login_required,        :except => [:request_password, :send_password, :new_token_from_jwt]
  before_action :manager_role_required, :except => [:show, :edit, :update, :request_password, :send_password, :change_password, :push_keys, :new_token, :new_token_from_jwt]
  before_action :admin_role_required,   :only =>   [:create_user_session]

  spurious_params_ban_ip :request_password => [],
                         :send_password    => [ :login, :email ],
                         :new_token_from_jwt => [ :jwt ]

  skip_before_action :verify_authenticity_token, :only => [ :new_token_from_jwt ]

  def index #:nodoc:
    @scope = scope_from_session
    scope_default_order(@scope, 'full_name')

    params[:name_like].strip! if params[:name_like]
    scope_filter_from_params(@scope, :name_like, {
      :attribute => 'full_name',
      :operator  => 'match'
    })

    @base_scope = current_user.available_users
    @users = @view_scope = @scope.apply(@base_scope)

    @scope.pagination ||= Scope::Pagination.from_hash({ :per_page => 50 })
    @users = @scope.pagination.apply(@view_scope, api_request?)

    # Precompute file, task and locked/unlocked counts.
    @users_file_counts    = Userfile.where(:user_id => @view_scope).group(:user_id).count
    @users_task_counts    = CbrainTask.real_tasks.where(:user_id => @view_scope).group(:user_id).count
    @locked_users_count   = @view_scope.where(:account_locked => true).count
    @unlocked_users_count = @view_scope.count - @locked_users_count

    scope_to_session(@scope)

    respond_to do |format|
      format.html # index.html.erb
      format.js
      format.xml  do
        render :xml  => @users.for_api_xml
      end
      format.json do
        render :json => @users.for_api
      end
    end
  end

  # GET /user/1
  # GET /user/1.xml
  # GET /user/1.json
  def show #:nodoc:
    @user = User.find(params[:id])

    cb_error "You don't have permission to view this user.", :redirect  => start_page_path unless edit_permission?(@user)

    @default_data_provider  = DataProvider.find_by_id(@user.meta["pref_data_provider_id"])
    @default_bourreau       = Bourreau.find_by_id(@user.meta["pref_bourreau_id"])
    @log                    = @user.getlog()

    # If needed, create a SSH key for the user
    @ssh_key = @user.ssh_key(create_it: true) rescue nil

    @active_sessions = LargeSessionInfo
      .where(:user_id => @user.id, :active => true)
      .where( "updated_at > ?", SessionHelpers::SESSION_API_TOKEN_VALIDITY.ago )
      .order(:updated_at)

    # Array of enabled OIDC providers configurations
    @oidc_configs = OidcConfig.all
    # Hash of OIDC uris with the OIDC name as key
    @oidc_uris    = generate_oidc_login_uri(@oidc_configs)

    respond_to do |format|
      format.html # show.html.erb
      format.xml  do
        render :xml  => @user.for_api_xml
      end
      format.json do
        # Append the SSH key to the JSON response if it exists
        render :json => @user.for_api.merge("public_key" => @ssh_key.try(:public_key))
      end
    end
  end

  def new #:nodoc:
    @user        = User.new
    @random_pass = User.random_string

    # Pre-load attributes based on signup ID given in path.
    if params[:signup_id].present?
      if signup = Signup.where(:id => params[:signup_id]).first # assignment, not comparison!
        @user  = signup.to_user # turn signup record into a pre-filled user object
        portal = signup.remote_resource
        form   = signup.form_page # a keyword like CBRAIN or NeuroHub
        flash.now[:notice]  = "Fields have been filled from a signup request.\n"
        flash.now[:notice] += "That request was performed on portal '#{portal.name}'.\n" if portal
        flash.now[:notice] += "The form used for the request was '#{form}'.\n"           if form
      end
    end
  end

  def create #:nodoc:
    new_user_attr = user_params

    no_password_reset_needed = params[:no_password_reset_needed] == "1"

    if current_user.has_role? :site_manager
      if new_user_attr[:type] == 'SiteManager'
        new_user_attr[:type] = 'SiteManager'
      else
        new_user_attr[:type] = 'NormalUser'
      end
    end

    if current_user.has_role?(:site_manager)
      new_user_attr[:site_id] = current_user.site_id
    end

    @user = User.new(new_user_attr)

    @user = @user.class_update

    @user.password_reset = no_password_reset_needed ? false : true

    if @user.save

      # This is not a real attribute of the model, and must be added after user is created
      add_meta_data_from_form(@user, [ :pref_data_provider_id, :allowed_globus_provider_names ])

      flash[:notice] = "User successfully created.\n"

      # Find signup record matching login name, and log creation and transfer some info.
      if signup = Signup.where(:id => params[:signup_id]).first
        current_user.addlog("Approved [[signup request][#{signup_path(signup)}]] for user '#{@user.login}'")
        @user.addlog("Account created after signup request approved by '#{current_user.login}'")
        signup.add_extra_info_for_user(@user)
        signup.approved_by = current_user.login
        signup.approved_at = Time.now
        signup.user_id     = @user.id
        signup.save
      else # account was not created from a signup request? Still log some info.
        current_user.addlog_context(self,"Created account for user '#{@user.login}'")
        @user.addlog_context(self,"Account created by '#{current_user.login}'")
      end

      if @user.email.blank? || @user.email =~ /example/i || @user.email !~ /@/
        flash[:notice] += "Since this user has no proper email address, no welcome email was sent."
      else
        if send_welcome_email(@user, signup, new_user_attr[:password], no_password_reset_needed)
          flash[:notice] += "A welcome email is being sent to '#{@user.email}'."
        else
          flash[:error] = "Could not send email to '#{@user.email}' informing them that their account was created."
        end
      end
      respond_to do |format|
        format.html { redirect_to users_path() }
        format.xml  { render :xml  => @user.for_api }
        format.json { render :json => @user.for_api }
      end
    else
      respond_to do |format|
        format.html { render :action => :new }
        format.xml  { render :xml  => @user.errors, :status => :unprocessable_entity }
        format.json { render :json => @user.errors, :status => :unprocessable_entity }
      end
    end
  end

  def change_password #:nodoc:
    @user = User.find(params[:id])
    if ! edit_permission?(@user)
       cb_error "You don't have permission to view this page.", :redirect => start_page_path
    end
    if user_must_link_to_oidc?(@user)
      cb_error "Your account can only authenticate with an OpenID identities providers.", :redirect => user_path(current_user)
    end
  end

  # PUT /users/1
  # PUT /users/1.xml
  def update #:nodoc:
    @user          = User.where(:id => params[:id]).includes(:groups).first
    cb_error "You don't have permission to update this user.", :redirect => start_page_path unless edit_permission?(@user)

    new_user_attr = user_params
    if new_user_attr[:group_ids] # the ID adjustment logic in this paragraph is awful FIXME
      # This makes sure the user stays in all his SystemGroups
      new_user_attr[:group_ids]   |= @user.groups.where(:type => SystemGroup.sti_descendant_names).pluck(:id).map(&:to_s)
      unless current_user.has_role?(:admin_user)
        # This makes sure the user stays in all his invisible and public WorkGroups
        new_user_attr[:group_ids] |= @user.groups.where(:type => WorkGroup.sti_descendant_names, :invisible => true).pluck(:id).map(&:to_s)
        new_user_attr[:group_ids] |= @user.groups.where(:type => WorkGroup.sti_descendant_names, :public    => true).pluck(:id).map(&:to_s)
      end
    end

    if new_user_attr[:password].present?
      if user_must_link_to_oidc?(@user)
        new_user_attr.delete(:password)
        new_user_attr.delete(:password_confirmation)
      end
      if current_user.id == @user.id
        @user.password_reset = false
      else
        @user.password_reset = params[:force_password_reset] != '0'
      end
    else
      new_user_attr.delete(:password)
      new_user_attr.delete(:password_confirmation)
    end

    if new_user_attr.has_key?(:time_zone) && (new_user_attr[:time_zone].blank? || !ActiveSupport::TimeZone[new_user_attr[:time_zone]])
      new_user_attr[:time_zone] = nil # change "" to nil
    end

    # IP whitelist
    params[:meta][:ip_whitelist].split(',').each do |ip|
      IPAddr.new(ip.strip) rescue cb_error "Invalid whitelist IP address: #{ip}"
    end if
      params[:meta] && params[:meta][:ip_whitelist]

    # For logging
    original_group_ids = @user.group_ids
    original_ap_ids    = @user.access_profile_ids


    if current_user.has_role? :site_manager
      if new_user_attr[:type] == 'SiteManager'
        new_user_attr[:type] = 'SiteManager'
      else
        new_user_attr[:type] = 'NormalUser'
      end
      @user.site = current_user.site
    end

    @user.attributes = new_user_attr

    remove_ap_ids    = original_ap_ids - @user.access_profile_ids
    remove_group_ids = remove_ap_ids.present? ? AccessProfile.find(remove_ap_ids).map(&:group_ids).flatten.uniq : []

    @user.apply_access_profiles(remove_group_ids: remove_group_ids)

    @user = @user.class_update

    success = false;
    if @user.save_with_logging(current_user, %w( full_name login email role city country account_locked ) )
      @user = User.find(@user.id) # fully reload with new class if needed
      @user.addlog_object_list_updated("Groups", Group, original_group_ids, @user.group_ids, current_user)
      @user.addlog_object_list_updated("Access Profiles", AccessProfile, original_ap_ids, @user.access_profile_ids, current_user)
      add_meta_data_from_form(@user, [:pref_bourreau_id, :pref_data_provider_id, :ip_whitelist, :allowed_globus_provider_names ])
      # Log AccessProfile modification
      added_ap_ids   = @user.access_profile_ids - original_ap_ids
      changed_ap_ids = remove_ap_ids + added_ap_ids
      changed_ap_ids.each do |id|
        ap                  = AccessProfile.find(id)
        ap_user_ids         = ap.user_ids
        initial_ap_user_ids = added_ap_ids.include?(id) ? ap_user_ids - [@user.id] : ap_user_ids + [@user.id]
        ap.addlog_object_list_updated("Users", User, initial_ap_user_ids, ap_user_ids,  current_user, :login)
      end
      success = true;
    end

    respond_to do |format|
      if success
        flash[:notice] = "User #{@user.login} was successfully updated."
        format.html  { redirect_to :action => :show }
        format.xml   { render :xml  => @user.for_api }
        format.json  { render :json => @user.for_api }
      else
        format.html do
          if new_user_attr[:password]
            render action: "change_password"
          else
            # Needed when rendering the 'show' form again.
            @oidc_configs = OidcConfig.all
            @oidc_uris    = generate_oidc_login_uri(@oidc_configs)
            render action: "show"
          end
        end
        format.xml  { render :xml  => @user.errors, :status => :unprocessable_entity }
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

  # API-only action for admin users only
  def create_user_session #:nodoc:
    for_user_id = params[:id]
    for_user    = User.find(for_user_id)

    new_user_session = LargeSessionInfo.new(
      user_id:    for_user_id,
      session_id: SecureRandom.hex,
      active: true,
      data: {
        guessed_remote_host: cbrain_session[:guessed_remote_host],
        guessed_remote_ip: cbrain_session[:guessed_remote_ip],
        api: true
      }
    )
    new_user_session.save!

    new_session_info = {
      cbrain_api_token: new_user_session.session_id,
      user_id:          for_user_id
    }

    render :json => new_session_info
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
    cbrain_session.clear

    # This does most of the work...
    self.current_user = @user
    # ... but we must adjust the CBRAIN session object too
    cbrain_session.user_id = @user.id

    redirect_to start_page_path
  end

  def request_password #:nodoc:
  end

  def send_password #:nodoc:
    @user = User.where( :login  => params[:login], :email  => params[:email] ).first

    if @user
      if user_must_link_to_oidc?(@user)
        contact = RemoteResource.current_resource.support_email.presence || User.admin.email.presence || "the support staff"
        wipe_user_password_after_oidc_link("password-rest", @user)  # for legacy or erroneously set users
        flash[:error] = "Your account can only authenticate with OpenID identities. Thus you are not allowed to use or reset password. Please contact #{contact} for help."
        respond_to do |format|
          format.html { redirect_to login_path }
          format.any { head :unauthorized }
        end
        return
      end
      if @user.account_locked?
        contact = RemoteResource.current_resource.support_email.presence || User.admin.email.presence || "the support staff"
        flash[:error] = "This account is locked, please write to #{contact} to get this account unlocked."
        respond_to do |format|
          format.html { redirect_to :action  => :request_password }
          format.xml  { head :unauthorized }
        end
        return
      end
      @user.password_reset = true
      @user.set_random_password
      if @user.save
        if send_forgot_password_email(@user)
          @user.addlog("Password reset by user to random string and email sent.")
          flash[:notice] = "#{@user.full_name}, your new password has been sent to you via e-mail. You should receive it shortly."
          flash[:notice] += "\nIf you do not receive your new password within 24hrs, please contact your admin."
        else
          @user.addlog("Password reset by user to random string BUT email FAILED to be sent.")
          flash[:error] = "Could not send an email with the reset password!\nPlease contact your admin."
        end
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

  def push_keys #:nodoc:
    @user = User.find(params[:id])
    cb_error "You don't have permission to update this user.", :redirect => user_path(@user) unless edit_permission?(@user)

    push_bids        = params[:push_keys_to].presence
    bourreau_to_push = Bourreau.find_all_accessible_by_user(@user).where(:id => push_bids).to_a
    ssh_key          = @user.ssh_key rescue nil

    cb_error "No servers selected (or accessible by user).", :redirect => user_path(@user) if bourreau_to_push.empty?
    cb_error "No user SSH key exists yet.",                  :redirect => user_path(@user) if ! ssh_key

    # Get ssh key pair
    pub_key  = ssh_key.public_key
    priv_key = ssh_key.send(:private_key, "I Know What I Am Doing")

    ok_list    = []
    error_list = []

    bourreau_to_push.each do |bourreau|
      command          = RemoteCommand.new(:command           => 'push_ssh_keys',
                                           :requester_user_id => @user.id,
                                           :ssh_key_pub       => pub_key,
                                           :ssh_key_priv      => priv_key,
                                          )

      answer = bourreau.send_command(command) rescue nil
      if answer&.command_execution_status == 'OK'
        ok_list << bourreau.name
      else
        error_list << bourreau.name
      end
    end

    respond_to do |format|
      format.html do
        flash[:notice] = "Pushed user SSH keys to: #{ok_list.join(', ')}"            if ok_list.present?
        flash[:error]  = "Failed to push user SSH keys to: #{error_list.join(', ')}" if error_list.present?
        redirect_to user_path(@user)
      end

      format.json do
        status = :ok
        status = :unprocessable_entity if error_list.present?
        render :json => { :pushed => ok_list, :failed => error_list }, :status => status
      end
    end
  end

  # POST /users/new_token
  # Currently the JSON version of this call is a bit dumb and could
  # be made more intelligent by reusing any available and valid tokens
  # that come from the same IP address. Right now, a new token is
  # always generated.
  def new_token
    new_session = cbrain_session.duplicate_with_new_token
    @new_token  = new_session.cbrain_api_token

    respond_to do |format|
      format.html
      format.json do
        render :json => { :cbrain_api_token => @new_token }
      end
    end
  end

  # POST /users/new_token_from_jwt
  #
  # This action allows an external service (called 'client' in the code)
  # to get a CBRAIN API token for a user using a shared secret. Each user
  # has their own secret for each client. For populating the CBRAIN side
  # secrets, see the methods in the User class.
  #
  # This action requires a small JSON object with a single key, :jwt,
  # whose value is an encoded JWT. E.g.
  #
  #   { "jwt": "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoyLCJ
  #             jbGllbnQiOiJ0ZXN0IiwiaWF0IjoxNzczNzcyNTI
  #             yLjc2NDAyMn0.7eeAoeH1ZBzuIJqKnGy6bn7R6th
  #             OCcTMQncPaett2Js" }
  #
  # In this example, the payload is
  #
  #   { "user_id": 2, "client" => "test", "iat": 1773772522.764022 }
  #
  # and it has been signed with HS256 using the shared common secret.
  #
  # The payload MUST contain "iat" and "client". "client" is any
  # simple alphanum name string that identify the external service,
  # chosen in agreement by the people making the integrations.
  #
  # The payload MUST contain a way to identify a CBRAIN user. Currently,
  # three ways are provided by three keys, which are tried in this order:
  #
  #   1. "user_id" or, if missing,
  #   2. "login" or, if missing,
  #   3. "email"
  #
  # The action returns a simple JSON object with a single JWT in exactly
  # the same way, signed using the same secret:
  #
  #   { "jwt": "eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoyLCJ
  #             jYnJhaW5fYXBpX3Rva2VuIjoiMDFkNmM5Nzg4YmM
  #             xODNhMmY0NjdlMzA0OTZlMGFiZmMiLCJpYXQiOjE
  #             3NzM3NzMzMzcuOTI2MzQ5Mn0.NjjDAt2sZNI8mI8
  #             Q3js_U4suzn_ACbKEDrSrqhSb0-E" }
  #
  # The JWT payload will contain only three values, as shown here:
  #
  #   {
  #     "user_id"=>2,
  #     "cbrain_api_token"=>"fc50499d5a073cb98b33fde3080af19f",
  #     "iat"=>1773772586.881768
  #   }
  #
  # Note that the CBRAIN session will be reused if the requests
  # happen to match a request sent a bit earlier. Also, the CBRAIN
  # session will always be tied to the IP address of the client.
  #
  # Anything that goes wrong generates a 401.
  def new_token_from_jwt

    unauthorized = ->(message) do
      Rails.logger.error "Unauthorized: #{message}"
      head :unauthorized
    end

    return unauthorized.('Not JSON') if ! api_request?
    jwtstring = params[:jwt].presence
    return unauthorized.('No JWT provided') if jwtstring.blank?
    jwt = JWT::EncodedToken.new(jwtstring)

    # First try to find a user ID using the unverified payload
    user        = nil
    danger_pl   = jwt.unverified_payload

    # Verify that we have a name for the client
    client = danger_pl["client"].to_s # name of service asking for token
    return unauthorized.('Bad/missing client name') if client.blank? || client !~ /^\A[a-z][a-z0-9_]*[a-z]+\z/i # letters digits numbers only

    # We try these three in order of priority
    user_id     = danger_pl["user_id"].to_s  # cbrain User numeric ID
    user_login  = danger_pl["login"].to_s    # cbrain User login
    user_email  = danger_pl["email"].to_s    # cbrain User email
    if user_id.present? && user_id =~ /\A\d+\z/
      user = NormalUser.find(user_id)
    elsif user_login.present?
      user = NormalUser.find_by_login(user_login)
    elsif user_email.present?
      user = NormalUser.where(:email => user_email).first
    else
      return unauthorized.('No user specified')
    end

    # Get the shared secret for the user/client pair
    secret = user.get_shared_secret_for_client(client)
    return unauthorized.("No shared secret for user #{user.login} from client #{client}") if secret.blank?

    # Now verify the JWT using the common secret.
    # This will raise JWT::VerificationError if the JWT is bad
    jwt.verify!( :signature => { :algorithm => jwt.header["alg"], :key => secret } )

    # Find the issue timestamp; must have been issued in the past hour
    timestamp = jwt.payload['iat'].to_f rescue nil # numeric date
    return unauthorized.('Bad IssuedAt field') unless timestamp && timestamp > DateTime.parse("2025-01-01").to_f
    return unauthorized.('IssuedAt is too far from present') if Time.now.to_f - timestamp > 3600.0 # one hour

    # Try to find an existing session, in case the client makes multiple requests
    ip_add = cbrain_request_remote_ip()
    ses = LargeSessionInfo.where(:user_id => user.id, :active => true).to_a.detect do |lsi|
      lsi.data[:api].present?                        &&
      lsi.data[:jwt_client]        == client         &&
      lsi.data[:guessed_remote_ip] == ip_add         &&
      lsi.updated_at > SessionHelpers::SESSION_API_TOKEN_VALIDITY.ago
    end

    Rails.logger.info "Re-using existing session" if ses

    # If we can't reuse a session, we create a new one
    if ses.blank?
      ses = LargeSessionInfo.new(
        :user_id    => user.id,
        :active     => true,
        :session_id => CbrainSession.random_session_id,
        :data => { :api               => 'yes',
                   :jwt_client        => client,
                   :jwt_iat           => timestamp.to_s,
                   :guessed_remote_ip => ip_add, # maybe leave blank and wait until first connection?
                 }
      )
      ses.save!
      Rails.logger.info "Creating new session"
    end

    # Create the encoded response JWT
    answer = JWT.encode(
      {
        :user_id          => user.id,
        :cbrain_api_token => ses.session_id,
        :iat              => Time.now.to_f,
      },
      secret,
      'HS256'
    )

    # Return the info
    render :json => { :jwt => answer }

  rescue JWT::VerificationError
    Rails.logger.error "Token verification failed"
    head :unauthorized
  end

  private

  def user_params #:nodoc:
    pseudo_attr  = [:password, :password_confirmation]
    pseudo_attr += [:group_ids => [], :access_profile_ids => []] if
                    current_user.has_role?(:site_manager) || current_user.has_role?(:admin_user)

    allowed     = [ :full_name, :email, :time_zone, :city, :country,
                    :zenodo_sandbox_token, :zenodo_main_token ] + pseudo_attr
    allowed    += [ :login, :type, :account_locked]             if current_user.has_role?(:site_manager)
    allowed     = User.column_names - ["id"] + pseudo_attr      if current_user.has_role?(:admin_user)

    params.require(:user).permit( allowed )
  end

  # Sends email and returns true/false if it succeeds/fails
  def send_welcome_email(user, signup, password, no_password_reset_needed) #:nodoc:
    mailer = signup.present? ? signup.action_mailer_class : CbrainMailer
    mailer.registration_confirmation(user,password,no_password_reset_needed).deliver
    return true
  rescue => ex
    Rails.logger.error ex.to_s
    return false
  end

  # Sends email and returns true/false if it succeeds/fails
  def send_forgot_password_email(user) #:nodoc:
    CbrainMailer.forgotten_password(user).deliver
    return true
  rescue => ex
    Rails.logger.error ex.to_s
    return false
  end

end
