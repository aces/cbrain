
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

    already_sent_to = Invitation.where(sender_id: current_user.id, active: true, group_id: @group.id).all.map(&:user_id)
    @users = current_user.visible_users.where("users.id NOT IN (?)", @group.users.map(&:id) | already_sent_to)
    render :partial => "new"
  end

  # Send an invitation
  def create #:nodoc:
    @group          = Group.find(params[:group_id])
    user_ids        = params[:user_ids].map(&:to_i)
    already_sent_to = Invitation.where(sender_id: current_user.id, active: true, user_id: user_ids, group_id: @group.id).all.map(&:user_id)
    rejected_ids    = user_ids & already_sent_to
    if rejected_ids.present?
      flash_message = "\n#{User.find(rejected_ids).map(&:login).join(", ")} already invited."
    end

    @users = User.find((user_ids - already_sent_to) & current_user.visible_users.map(&:id))

    unless @group.can_be_edited_by?(current_user) && @users.present?
      flash[:error]  = "Could not send the requested invitations."
      flash[:error] += flash_message if rejected_ids.present?
      respond_to do |format|
       format.html { redirect_to group_path(@group) }
       format.xml  { head :forbidden }
      end
      return
    end

    if @users.present?
      Invitation.send_out(current_user, @group, @users)
      flash[:notice] = "Your invitations were successfully sent."
    else
      flash[:notice] = "No new users were found to invite."
    end

    flash[:notice] += flash_message if rejected_ids.present?

    respond_to do |format|
     format.html { redirect_to group_path(@group) }
     format.xml  { head :ok }
    end
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
                         :variable_text  => "User #{current_user.login} accepted your invitation and joined project #{@invitation.group.name}"
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
