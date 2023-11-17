
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

# Superclass to all *NeuroHub* controllers.
# Already inherits all the methods and modules of
# CBRAIN's ApplicationController.
class NeurohubApplicationController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include NeurohubHelpers

  before_action :switch_to_neurohub_layout
  before_action :prepare_nh_messages

  # This before_action callback sets a instance
  # variable @_NeuroHubLayout_ which is used by
  # the views to render pages with the NeuroHub
  # layout code.
  #
  # See also BrainPortal/app/views/layouts/application.html.erb
  def switch_to_neurohub_layout
    @_NeuroHubLayout_ = true
  end

  # This is identical to the method in authenticated_system.rb
  # except it redirects to the NeuroHub login page.
  def access_denied(message = 'You must login to see this page.') #:nodoc:
    respond_to do |format|
      format.html do
        store_location
        flash[:error] = message
        redirect_to signin_path
      end
      format.any do
        head :unauthorized
      end
    end
  end

  # Redirect normal users to the login page if the portal is locked.
  # This is identical to the method in permission_helpers.rb
  # except it redirects to the NeuroHub login page.
  def check_if_locked
    return true if ! BrainPortal.current_resource.portal_locked?

    # Build message
    flash.now[:error] ||= ""
    flash.now[:error] += "\n" unless flash.now[:error].blank?
    flash.now[:error] += "This NeuroHub portal is currently locked for maintenance."
    message = BrainPortal.current_resource.meta[:portal_lock_message]
    flash.now[:error] += "\n#{message}" unless message.blank?

    # Admin users stay logged in.
    return true if current_user && current_user.has_role?(:admin_user)

    # Other users get logged out.
    respond_to do |format|
      format.html  { redirect_to signout_path unless params[:controller].to_s =~ /sessions/ }
      format.xml   { render :xml  => {:message => message}, :status => :service_unavailable }
      format.json  { render :json => {:message => message}, :status => :service_unavailable }
    end

  end

  # overrides check_license_agreements, as list of NeuroHub licenses may differ from cbrains
  def check_license_agreements #:nodoc:

    current_user.meta.reload
    return true if current_user.neurohub_licenses_signed.present?
    return true if params[:controller] == "neurohub_portal" && params[:action] =~ /license$/
    return true if params[:controller] == "nh_users"  && (params[:action] == "change_password" || params[:action] == "update")

    unsigned_agreements = current_user.neurohub_unsigned_license_agreements
    unless unsigned_agreements.empty?
      if File.exists?(Rails.root + "public/licenses/#{unsigned_agreements.first}.html")
        respond_to do |format|
          format.html { redirect_to :controller => :neurohub_portal, :action => :nh_show_license, :license => unsigned_agreements.first }
          format.json { render :status => 403, :json => { "error" => "Some license agreements are not signed." } }
          format.xml  { render :status => 403, :xml  => { "error" => "Some license agreements are not signed." } }
        end
        return false
      end
    end

    current_user.neurohub_licenses_signed = "yes"
    return true
  end

  ########################################################################
  # Messaging System Filters (presently only invite acceptance)
  ########################################################################

  # Find the number of new invitations and messages to be displayed at the top of the page.
  def prepare_nh_messages
    return unless current_user
    nh_invites            = Invitation.where(user_id: current_user.id, active: true).all || [];
    nh_new_invites        = Invitation.where(user_id: current_user.id, active: true, read: false).all || [];
    @nh_invites_count     = nh_invites.count
    @nh_new_invites_count = nh_new_invites.count
    @nh_message_count     = find_nh_messages.count
    @nh_new_message_count = find_nh_messages.where(:read => false).count  # differs from cbrain, as invites are shown separately
    @nh_new_invites_ack   = current_user.messages.where( :read => false, :header => 'Invitation Accepted' ).order( "last_sent DESC" ).all()
  end

  # Check if password need to be reset.
  # This method is identical to (and overrides) the one in
  # ApplicationController excepts it uses the NeuroHub password reset form.
  def check_password_reset #:nodoc:
    if current_user.password_reset
      unless params[:controller] == "nh_users" && (params[:action] == "change_password" || params[:action] == "update")
        flash[:error] = "Please reset your password."
        redirect_to change_password_nh_users_path
        return false
      end
    end
    return true
  end

  # Check to see if the user HAS to link their account to
  # a globus identity. If that's the case and not yet done,
  # redirects to the page that provides the user with the
  # buttons and explanations.
  # This method is similar to (and overrides) the one in
  # ApplicationController excepts it uses the NeuroHub information form.
  def check_mandatory_globus_id_linkage #:nodoc:
    return true if   params[:action].to_s == "nh_mandatory_globus"
    return true if   params[:action].to_s == "nh_globus"
    return true if ! user_must_link_to_globus?(current_user)
    return true if   user_has_link_to_globus?(current_user)
    respond_to do |format|
      format.html { redirect_to :controller => :nh_sessions, :action => :nh_mandatory_globus }
      format.json { render :status => 403, :json => { "error" => "This account must first be linked to a Globus identity" } }
      format.xml  { render :status => 403, :xml  => { "error" => "This account must first be linked to a Globus identity" } }
    end
    return false
  end


end

