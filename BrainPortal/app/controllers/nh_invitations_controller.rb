
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

  def index #:nodoc:
    @nh_invitations = Message.where(:user_id => current_user.id, :active => true)
  end

  def new #:nodoc:
    @nh_project = find_nh_project(current_user, params[:nh_project_id])
  end

  def create #:nodoc:
    @nh_project     = find_nh_project(current_user, params[:nh_project_id])
    user_emails     = (params[:emails].presence.try(:strip) || "").split(/[\s,]+/)
    user_emails     = user_emails.map(&:presence).compact
    cb_error "Please specify at least one email address", :redirect => nh_project_path(@nh_project) if user_emails.empty?
    users           = User.where(:email => user_emails)
    user_ids        = users.pluck(:id)
    found_emails    = users.pluck(:email)
    wrong_emails    = user_emails - found_emails

    flash_messages = []
    if wrong_emails.present?
      flash_messages << "\nWe are not able to invite user(s) with email(s) #{wrong_emails.join(", ")}. At the moment users are matched by email that they are used to register in NeuroHub. Please confirm with them which email they provided to NeuroHub. "
    end

    already_sent_to = Invitation.where(active: true, user_id: user_ids, group_id: @nh_project.id).pluck(:user_id)
    rejected_ids    = user_ids & already_sent_to
    if rejected_ids.present?
      flash_messages <<  "\n#{User.find(rejected_ids).map(&:login).join(", ")} already invited."
    end

    @users = User.find(user_ids - already_sent_to - @nh_project.user_ids)

    if @users.present?
      Invitation.send_out(current_user, @nh_project, @users)
      flash[:notice] = "Your invitations were successfully sent."
    else
      flash[:error] = "No new users were found to invite."
    end

    if flash_messages.present?
      flash[:notice] = flash_messages.join
    end

    redirect_to nh_project_path(@nh_project)
  end


  # Accept an invitation
  def update #:nodoc:
    @nh_invitation = Invitation.where(user_id: current_user.id).find(params[:id])

    unless @nh_invitation.try(:active?)
      flash[:error] = "This invitation has already been accepted.\nPlease contact the project owner if you wish to be invited again."
      redirect_to nh_projects_path
      return
    end

    if params[:read]
      @nh_invitation.read = true
      @nh_invitation.save

      respond_to do |format|
        format.html { redirect_to nh_invitations_path }
        format.xml  { head :ok }
      end
      return
    end

    @nh_project = @nh_invitation.group

    unless @nh_project
      @nh_invitation.destroy
      
      flash[:notice] = "This project does not exist anymore."
      redirect_to nh_projects_path
      return
    end

    unless @nh_project.users.include?(current_user)
      @nh_project.users << current_user
    end

    @nh_invitation.active = false
    @nh_invitation.save

    flash[:notice] = "You have been added to project #{@nh_project.name}."
    redirect_to nh_projects_path
  end

  # Delete an invitation
  def destroy #:nodoc:
    @nh_invitation = Invitation.where(user_id: current_user.id).find(params[:id])
    @nh_project = @nh_invitation.group

    @nh_invitation.destroy

    flash[:notice] = "You have declined an invitation to #{@nh_project.name}."
    redirect_to nh_invitations_path
  end

end
