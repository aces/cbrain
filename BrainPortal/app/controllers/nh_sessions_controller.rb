
#
# NeuroHub Project
#
# Copyright (C) 2020
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

# Session management for NeuroHub
class NhSessionsController < NeurohubApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include OrcidHelpers

  before_action :login_required,    :except => [ :new, :create, :request_password, :send_password, :orcid ]
  before_action :already_logged_in, :except => [ :orcid, :destroy ]

  def new #:nodoc:
    @orcid_uri = orcid_login_uri()
  end

  # POST /nhsessions
  # Users log in with username and password
  def create #:nodoc:
    username = params[:username] # in CBRAIN we use 'login'
    password = params[:password]

    # Ugly cross-controller invocation... :-(
    # FIXME
    all_ok, new_cb_session = eval_in_controller(::SessionsController) do
      user = User.authenticate(username,password) # can be nil if it fails
      ok   = create_from_user(user, 'NeuroHub')
      [ok, cbrain_session]
    end
    @cbrain_session = new_cb_session # crush the session object that was created for the NhSessionsController

    if ! all_ok
      flash[:error] = 'Invalid username or password.'
      redirect_to signin_path
      return
    end

    # Record that the user connected using the NeuroHub login page
    cbrain_session[:login_page] = 'NeuroHub'

    redirect_to neurohub_path
  end

  # GET /signout
  def destroy
    reset_session
    redirect_to signin_path
  end

  def request_password #:nodoc:
  end

  def send_password #:nodoc:
  end

  # POST /orcid
  # Users log in with ORCID authentication, or if already
  # logged in, links their account to their ORCID account
  def orcid #:nodoc:
    code = params[:code].presence
    if code.blank?
      redirect_to signin_path
      return
    end

    myself              = RemoteResource.current_resource
    site_uri            = myself.site_url_prefix.presence.try(:strip)
    orcid_client_id     = myself.meta[:orcid_client_id].presence.try(:strip)
    orcid_client_secret = myself.meta[:orcid_client_secret].presence.try(:strip)

    if site_uri.blank? || orcid_client_id.blank? || orcid_client_secret.blank?
      flash[:error] = 'ORCID authentication not configured on this service.'
      redirect_to signin_path
      return
    end

    # Query ORCID, get a JSON record with an ORCID iD.
    response = Typhoeus.post(ORCID_TOKEN_URI,
      :body   => {
                   :code          => code,
                   :client_id     => orcid_client_id,
                   :client_secret => orcid_client_secret,
                   :grant_type    => 'authorization_code',
                   :redirect_uri  => orcid_url, # is this needed?
                 },
      :headers => { :Accept       => 'application/json' }
    )

    # Extract the ORCID iD of the user
    body  = response.response_body
    json  = JSON.parse(body)
    orcid = json['orcid'].presence
    Rails.logger.info "ORCID reply: #{json.to_h.hide_filtered.inspect}"

    if orcid.blank?
      redirect_to neurohub_path
      return
    end

    if current_user.blank?
      login_with_orcid(orcid)
    else
      record_user_orcid(orcid)
    end

  rescue => ex
    clean_bt = Rails.backtrace_cleaner.clean(ex.backtrace || [])
    Rails.logger.info "ORCID auth failed: #{ex.class} #{ex.message} at #{clean_bt[0]}"
    flash[:error] = 'The ORCID authentication failed'
    redirect_to signin_path
  end

  private

  def record_user_orcid(orcid) #:nodoc:
    current_orcid = current_user.meta[:orcid].presence.try(:strip)

    if current_orcid == orcid
      flash[:notice] = "Your ORCID ID is unchanged."
      redirect_to myaccount_path
      return
    end

    if current_orcid.blank?
      flash[:notice] = "Your ORCID ID has been recorded."
    else
      flash[:notice] = "Your ORCID ID has been updated."
    end

    current_user.meta[:orcid] = orcid # auto-saves
    current_user.touch
    current_user.addlog("Set ORCID to #{orcid}")
    redirect_to myaccount_path
  end

  def login_with_orcid(orcid)
    # Find the users that have it. Hopefully, only one.
    users = User.find_all_by_meta_data(:orcid, orcid)

    if users.size == 0
      flash[:error] = "No NeuroHub user matches your ORCID iD. Create a NeuroHub account, or add your ORCID ID to your NeuroHub account."
      redirect_to signin_path
      return
    elsif users.size > 1
      flash[:notice] = "Several NeuroHub user accounts matches your ORCID iD. Using the most recently updated one."
      users = [ users.sort_by(&:updated_at).last ]
    end
    user = users.first

    # Login by hijacking CBRAIN's system
    all_ok, new_cb_session = eval_in_controller(::SessionsController) do
      ok  = create_from_user(user, 'NeuroHub/ORCID')
      [ok, cbrain_session]
    end
    @cbrain_session = new_cb_session # crush the session object that was created for the NhSessionsController

    if ! all_ok
      redirect_to signin_path
      return
    end

    # All's good
    redirect_to neurohub_path
  end

  # before_action callback
  def already_logged_in
    if current_user
      respond_to do |format|
        flash[:notice] = 'You are already logged in.'
        format.html { redirect_to neurohub_path }
      end
    end
  end

  # Messy utility, poking through layers. Tricky and brittle.
  # Taken from CarminController, should be extracted into a module
  def eval_in_controller(mycontroller, options={}, &block) #:nodoc:
    cb_error "Controller is not a ApplicationController?" unless mycontroller < ApplicationController
    cb_error "Block needed." unless block_given?
    context = mycontroller.new
    context.request = self.request
    if options.has_key?(:define_current_user)
      context.define_singleton_method(:current_user) { options[:define_current_user] }
    end
    context.instance_eval(&block)
  end

end
