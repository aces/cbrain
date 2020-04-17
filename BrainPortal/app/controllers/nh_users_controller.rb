
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

  def update
    @user = User.find(params[:id])

    unless @user.id == current_user.id
      cb_error "You don't have permission to edit this user or user does not exists.", :redirect  => :neurohub
    end

    attr_to_update = params.require_as_params(:user).permit([ :full_name, :email, :time_zone,
           :city, :country, :affiliation, :position, :zenodo_sandbox_token, :zenodo_main_token ] )

    # Do not zap tokens if the user left them blank
    attr_to_update.delete(:zenodo_sandbox_token) if attr_to_update[:zenodo_sandbox_token].blank?
    attr_to_update.delete(:zenodo_main_token)    if attr_to_update[:zenodo_main_token].blank?

    if @user.update_attributes_with_logging(attr_to_update, current_user)
      add_meta_data_from_form(@user, [:orcid])
      flash[:notice] = "User #{@user.login} was successfully updated."
      #todo confirm email
      redirect_to :action => :myaccount
    else
      flash.now[:error] = "User #{@user.login} was not successfully updated." #unuser anyways
    end
  end

end
