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

# NeuroHub controller for Messages.
class NhMessagesController < NeurohubApplicationController
  Revision_info = CbrainFileRevision[__FILE__] #:nodoc:

  include Pagy::Backend

  before_action :login_required

  # GET /messages
  # GET /messages.xml
  def index #:nodoc:
    @messages        = find_nh_messages(current_user)
    @messages_count  = @messages.count
    @read_count      = @messages.where(:user_id => current_user.id, :read => true).count
    @unread_count    = @messages.where(:user_id => current_user.id, :read => false).count
    @page, @per_page = pagination_check(@messages, :nh_messages)
    @pagy, @messages = pagy(@messages, :items => @per_page)
  end

  def new #:nodoc:
    @message        = Message.new # blank object for new() form.
    @message.header = "A personal message from #{current_user.full_name.presence || current_user.login}"
    @recipients     = find_nh_message_recipients(current_user)
  end

  # POST /messages
  # POST /messages.xml
  def create #:nodoc:
    @message              = Message.new(message_params)
    @message.message_type = :communication
    @message.sender_id    = current_user.id

    @recipients = find_nh_message_recipients(current_user)

    @message.validate_input
    @destination_group_id = params['destination_group_id']
    if @destination_group_id.present?
      if @recipients.map(&:id).include?(@destination_group_id.to_i)
        destination_group = Group.find(@destination_group_id)
      else
        @message.errors.add(:destination_group_id, '(the selected destination is not available, perhaps, a project membership changed recently)' )
      end
    else
      @message.errors.add(:destination_group_id, 'You have to select message recipient(s)' )
    end

    if @message.errors.empty?
      @message.send_me_to(destination_group)
      flash.now[:notice] = 'Message was successfully sent.'
      redirect_to :action => :index
    else
      render :action => :new
    end
  end

  # DELETE /messages/1
  # DELETE /messages/1.xml
  def destroy #:nodoc:
    if current_user.has_role?(:admin_user)
      @message = Message.find(params[:id]) rescue nil
    else
      @message = current_user.messages.find(params[:id]) rescue nil
    end
    @message && @message.destroy

    redirect_to :action => :index
  end

  private

  def message_params
    params.require(:message).permit(:header, :description)
  end
end
