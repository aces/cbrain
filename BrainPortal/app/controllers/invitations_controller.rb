
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

#RESTful controller for the Group resource.
class InvitationsController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required

  # Create an invitation
  def new #:nodoc:
    @group = Group.find(params[:group_id])

    unless @group.can_be_edited_by?(current_user)
       flash[:error] = "You don't have permission send invitations for this project."
       respond_to do |format|
        format.html { redirect_to group_path(@group) }
        format.xml  { head :forbidden }
       end
       return
    end

    already_sent_to = Invitation.where(sender_id: current_user.id, active: true, invitation_group_id: @group.id).all.map(&:user_id)
    @users = current_user.visible_users.where("users.id NOT IN (?)", @group.users.map(&:id) | already_sent_to)
    render :partial => "new"
  end

  # Send an invitation
  def create #:nodoc:
    @group          = Group.find(params[:group_id])

    unless @group.can_be_edited_by?(current_user)
       flash[:error] = "You don't have permission send invitations for this project."
       respond_to do |format|
        format.html { redirect_to group_path(@group) }
        format.xml  { head :forbidden }
       end
       return
    end

    # The form allows users to invite by emails or usernames, even though
    # the parameter is only called :emails
    user_specs      = (params[:emails].presence.try(:strip) || "").split(/[\s,]+/)
    user_specs      = user_specs.map(&:presence).compact

    if user_specs.empty?
      cb_error "Please specify at least one email address or username", :redirect => group_path(@group)
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

    flash_notice = []
    flash_errors = []
    if not_found_specs.present?
      flash_errors.push <<-MESSAGE
        We are not able to invite user(s) identified by: #{not_found_specs.join(", ")}.
        At the moment users are matched by emails or usernames.
        Please confirm with your collaborators which email or username they use in CBRAIN.
      MESSAGE
    end

    # Which invitations are pending?
    already_sent_to = Invitation.where(active: true, user_id: user_ids, invitation_group_id: @group.id).pluck(:user_id)
    rejected_ids    = user_ids & already_sent_to
    if rejected_ids.present?
      already_logins = User.where(:id => rejected_ids).pluck(:login).join(", ")
      flash_errors.push "Already invited: #{already_logins}"
    end

    # List of newly invited users
    invited_users = User.find(user_ids - already_sent_to - @group.user_ids)
    if invited_users.present?
      Invitation.send_out(current_user, @group, invited_users)
      flash_notice.push "Your invitation was successfully sent to #{view_pluralize(invited_users.size,"user")}"
    else
      flash_errors.push "No new users were found to invite."
    end

    flash[:notice]  = flash_notice.join "\n" if flash_notice.present?
    flash[:error]   = flash_errors.join "\n" if flash_errors.present?

    redirect_to group_path(@group)
  end

  # Accept an invitation
  def update #:nodoc:
    @invitation = Invitation.where(user_id: current_user.id).find(params[:id])

    unless @invitation.try(:active?)
      flash[:error] = "This invitation has already been used.\nPlease contact the project owner if you wish to be invited again."
      respond_to do |format|
       format.html { redirect_to groups_path }
       format.xml  { head :forbidden }
      end
      return
    end

    @group = @invitation.group

    unless @group.users.include?(current_user)
      @group.users << current_user
    end

    @invitation.active = false
    @invitation.save

    flash[:notice] = "You have been added to project #{@group.name}."

    Message.send_message(@invitation.sender,
                         :message_type   => 'notice',
                         :header         => "Invitation Accepted",
                         :description    => "A user joined project #{@group.name}",
                         :variable_text  => "#{current_user.login} accepted your invitation and joined project #{@group.name}"
    )

    respond_to do |format|
      format.html { redirect_to groups_path }
      format.xml  { head :ok }
     end
  end

  def destroy #:nodoc:
    @invitation = Invitation.where(sender_id: current_user.id, active: true).find(params[:id])
    @user  = @invitation.user
    @group = @invitation.group

    @invitation.destroy

    flash[:notice] = "Invitation to #{@user.login} has been canceled."
    respond_to do |format|
      format.html { redirect_to group_path(@group) }
      format.xml  { head :ok }
     end
  end


end
