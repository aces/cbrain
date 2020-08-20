
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

#Controller for the User resource.
class NhUsersController < NeurohubApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required

  def show #:nodoc:
    @user = User.find(params[:id])
    unless current_user.available_users.to_a.include?(@user)
      cb_error "You don't have permission to view this user.", :redirect => :neurohub
      # probably not needed until admin/manager etc added...
    end
  end

  def myaccount #:nodoc:
    @user=current_user
    render :show
  end

  def edit #:nodoc:
    @user = User.find(params[:id])
    unless @user.id == current_user.id
      cb_error "You don't have permission to view this user.", :redirect => :neurohub
      # to change if admin/manager etc added...
      # todo move to security helpers
    end
  end

  def change_password #:nodoc:
    @user = current_user
  end

  def update
    @user = User.find(params[:id])

    unless @user.id == current_user.id
      cb_error "You don't have permission to edit this user or user does not exists.", :redirect  => :neurohub
    end

    attr_to_update = params.require_as_params(:user).permit( [
      :full_name, :email, :time_zone, :password, :password_confirmation,
      :city, :country, :affiliation, :position, :zenodo_sandbox_token, :zenodo_main_token
    ])

    # Do not zap tokens if the user left them blank
    attr_to_update.delete(:zenodo_sandbox_token) if attr_to_update[:zenodo_sandbox_token].blank?
    attr_to_update.delete(:zenodo_main_token)    if attr_to_update[:zenodo_main_token].blank?

    last_update = @user.updated_at
    if @user.update_attributes_with_logging(attr_to_update, current_user)
      add_meta_data_from_form(@user, [:orcid])
      if attr_to_update[:password].present?
        flash[:notice] = "Your password was changed."
        @user.update_column(:password_reset, false)
        redirect_to nh_projects_path
      else
        flash[:notice] = "User #{@user.login} was successfully updated." if @user.updated_at != last_update
        redirect_to :action => :myaccount
      end
    else
      if attr_to_update[:password].present?
        render :action => :change_password
      else
        render :action => :edit
      end
    end
  end

  # POST /users/new_token
  def new_token
    new_session = cbrain_session.duplicate_with_new_token
    @new_token  = new_session.cbrain_api_token
  end

end
