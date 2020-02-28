
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

# Invitation management for NeuroHub
class NhInvitationsController < NeurohubApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required

  def new #:nodoc:
    @nh_project_id = find_nh_project(current_user, params[:nh_project_id]).id
  end

  def create #:nodoc:
    @nh_project     = find_nh_project(current_user, params[:nh_project_id])
    user_email      = params[:email]
    user_ids        = User.where(:email => user_email).pluck(:id)

    already_sent_to = Invitation.where(active: true, user_id: user_ids, group_id: @nh_project.id).all.map(&:user_id)
    rejected_ids    = user_ids & already_sent_to
    if rejected_ids.present?
      flash_message = "\n#{User.find(rejected_ids).map(&:login).join(", ")} already invited."
    end

    @users = User.find((user_ids - already_sent_to)) - @nh_project.users

    if @users.present?
      Invitation.send_out(current_user, @nh_project, @users)
      flash[:notice] = "Your invitations were successfully sent."
    else
      flash[:error] = "No new users were found to invite."
    end

    flash[:notice] += flash_message if rejected_ids.present?

    redirect_to nh_project_path(@nh_project)
  end

end
