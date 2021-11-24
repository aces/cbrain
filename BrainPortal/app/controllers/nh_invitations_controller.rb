
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
    @nh_project = find_nh_project(current_user, params[:nh_project_id], allow_own_group: false)
  end

  def create #:nodoc:
    @nh_project     = find_nh_project(current_user, params[:nh_project_id], allow_own_group: false)

    # The form allows users to invite by emails or usernames, even though
    # the parameter is only called :emails
    user_specs      = (params[:emails].presence.try(:strip) || "").split(/[\s,]+/)
    user_specs      = user_specs.map(&:presence).compact

    if user_specs.empty?
      cb_error "Please specify at least one email address or username", :redirect => nh_project_path(@nh_project)
    end

    # Fetch the users
    uids_by_email   = User.where(:email => user_specs).pluck(:id)
    uids_by_uname   = User.where(:login => user_specs).pluck(:id)
    user_ids        = uids_by_email | uids_by_uname
    found_users     = User.where(:id => user_ids).to_a
    found_specs     = user_specs.select do |spec|
      found_users.any? { |u| u.login == spec || u.email == spec }
    end

    # Ok, which ones are not found?
    not_found_specs = user_specs - found_specs

    flash_warnings = []
    flash_errors   = []
    if not_found_specs.present?
      flash_errors.push <<-MESSAGE
        We are not able to invite user(s) identified by: #{not_found_specs.join(", ")}.
        At the moment users are matched by emails or usernames.
        Please confirm with your collaborators which email or username they use in NeuroHub.
      MESSAGE
    end

    # Which invitations are pending?
    already_sent_to = Invitation.where(active: true, user_id: user_ids, group_id: @nh_project.id).pluck(:user_id)
    rejected_ids    = user_ids & already_sent_to
    if rejected_ids.present?
      already_logins = User.where(:id => rejected_ids).pluck(:login).join(", ")
      flash_warnings.push "Already invited: #{already_logins}"
    end

    # List of newly invited users
    invited_users = User.find(user_ids - already_sent_to - @nh_project.user_ids)
    if invited_users.present?
      Invitation.send_out(current_user, @nh_project, invited_users)
      flash[:notice] = "Your invitation was successfully sent to #{view_pluralize(invited_users.size,"user")}"
    else
      flash_errors << "No new users were found to invite."
    end

    flash[:warning] = flash_warnings.join "\n"      if flash_warnings.present?
    flash[:error]   = flash_errors.join   "\n"      if flash_errors.present?

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

    Message.send_message(@nh_invitation.sender,
                         :message_type   => 'notice',
                         :header         => "Invitation Accepted",
                         :description    => "A user joined project #{@nh_project.name}",
                         :variable_text  => "#{current_user.login} accepted your invitation to join project #{@nh_project.name} via NeuroHub"
    )
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
