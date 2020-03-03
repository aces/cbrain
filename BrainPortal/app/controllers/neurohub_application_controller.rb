
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

  # ------------------

  # Code below is temporary, while in development.
  # Will be removed at the same time as the rest of the reboot mechanism.
  before_action :check_if_rebooting
  def check_if_rebooting #:nodoc:
    if File.exists?("public/reboot_in_progress")
      render :plain => File.read('public/reboot.txt').gsub(/\e\[[\d;]+m/,"")
    end
    true
  end

end

