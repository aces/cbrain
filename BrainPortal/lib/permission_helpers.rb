
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

# Controller helpers for handling authentication and permissions.
module PermissionHelpers

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.included(includer) #:nodoc:
    includer.class_eval do
      helper_method :check_role, :not_admin_user, :edit_permission?, :delete_permission?
      before_action :check_if_locked
    end
  end

  # Checks that the current user's has at least the rights associated
  # with +role+.
  def check_role(role)
    current_user && current_user.has_role?(role)
  end

  # Checks that the current user is not the default *admin* user.
  def not_admin_user(user)
    user && user.login != 'admin'
  end

  # Checks that the current user is the same as +user+. Used to ensure permission
  # for changing account information.
  def edit_permission?(user)
    current_user && user && (current_user == user || current_user.has_role?(:admin_user) || (current_user.has_role?(:site_manager) && current_user.site == user.site))
  end

  # Used to ensure that +user+ has the permissions to delete the current object.
  def delete_permission?(user)
    current_user && user && user != User.admin && current_user != user &&
    (current_user.has_role?(:site_manager) || current_user.has_role?(:admin_user)) && current_user.available_users.include?(user)
  end

  # Helper method to render and error page. Will render public/<+status+>.html
  def access_error(status)
    respond_to do |format|
      format.html { render(:file => (Rails.root.to_s + '/public/' + status.to_s), :status  => status, :layout => false ) }
      format.xml  { head status }
    end
  end

  # Redirect normal users to the login page if the portal is locked.
  def check_if_locked
    if BrainPortal.current_resource.portal_locked?
      flash.now[:error] ||= ""
      flash.now[:error] += "\n" unless flash.now[:error].blank?
      flash.now[:error] += "This portal is currently locked for maintenance."
      message = BrainPortal.current_resource.meta[:portal_lock_message]
      flash.now[:error] += "\n#{message}" unless message.blank?
      unless current_user && current_user.has_role?(:admin_user)
        respond_to do |format|
          format.html {redirect_to logout_path unless params[:controller] == "sessions"}
          format.xml  {render :xml => {:message => message}, :status => 503}
        end
      end
    end
  end
end

