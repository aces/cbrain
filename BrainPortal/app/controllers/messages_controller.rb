
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

# RESTful controller for managing Messages.
class MessagesController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  before_action :login_required
  before_action :manager_role_required, :only  => :create

  # GET /messages
  # GET /messages.xml
  def index #:nodoc:
    @scope = scope_from_session
    scope_default_order(@scope, 'last_sent', :desc)

    @base_scope = Message.where(nil)
    @base_scope = @base_scope.where(:user_id => current_user.available_users.pluck(:id)) unless
      current_user.has_role?(:admin_user)
    # no need to distract admins and managers with personal communicaitons
    @base_scope = @base_scope.where.not( :message_type =>  :communication).or(
      @base_scope.where( :message_type =>  :communication, :user_id => current_user.id))
    @view_scope = @messages = @scope.apply(@base_scope)

    @read_count   = @view_scope.where(:user_id => current_user.id, :read => true).count
    @unread_count = @view_scope.where(:user_id => current_user.id, :read => false).count

    @scope.pagination ||= Scope::Pagination.from_hash({ :per_page => 25 })
    @messages = @scope.pagination.apply(@view_scope)

    scope_to_session(@scope)

    respond_to do |format|
      format.html # index.html.erb
      format.js   # annoying, used only because of pagination
      format.xml  { render :xml => @messages }
    end
  end

  def new #:nodoc:
    @message  = Message.new # blank object for new() form.
    @group_id = nil         # for new() form

    if params[:for_dashboard]
      @message.message_type = (params[:for_dashboard].to_s =~ /neurohub/i ? 'neurohub_dashboard' : 'cbrain_dashboard')
      render 'new_dashboard'
      return
    end
    # Otherwise, we just render 'new'
  end

  # POST /messages
  # POST /messages.xml
  #
  # In CBRAIN, only an admin can create new messages.
  def create #:nodoc:
    @message  = Message.new(message_params)
    @group_id = params[:group_id] # destination; this is NOT the group_id IN the message object!

    if @message.message_type == 'cbrain_dashboard' || @message.message_type == 'neurohub_dashboard'
      @group_id = current_user.own_group.id # these notifications always belong to the admin who created them
    end

    date = params[:expiry_date] || ""
    hour = params[:expiry_hour] || "00"
    min  = params[:expiry_min]  || "00"
    date = Date.today if date.blank? && (hour != "00" || min != "00")
    unless date.blank?
      string_time = "#{date} #{hour}:#{min} #{Time.now.in_time_zone.formatted_offset}"
      full_date = DateTime.parse(string_time)
      @message.expiry = full_date
    end

    if @message.header.blank?
      @message.errors.add(:header, "cannot be left blank.")
    end

    if @group_id.blank?
      @message.errors.add(:base, "You need to specify the project whose members will receive this message.")
    elsif @message.errors.empty?
      group = current_user.assignable_groups.find(@group_id)
      if group
        @message.send_me_to(group)
      else
        @message.errors.add(:base, "Invalid project specified for message destination.")
      end
    end
    prepare_messages

    respond_to do |format|
      if @message.errors.empty?
        flash.now[:notice] = 'Message was successfully sent.'
        format.xml  { render :xml => @message, :status => :created, :location => @message }
        format.html { redirect_to :action => :index }
      else
        format.xml  { render :xml => @message.errors, :status => :unprocessable_entity }
        format.html { render :action => :new  }
      end
    end
  end

  # PUT /messages/1
  # PUT /messages/1.xml
  def update #:nodoc:
    if current_user.has_role? :admin_user
      @message = Message.find(params[:id])
    else
      @message = current_user.messages.find(params[:id])
    end

    # It seems we only support changing the read/unread attribute.
    respond_to do |format|
      if @message.update_attributes(:read =>  params[:read])
        format.xml  { head :ok }
        format.js   { head :ok }
      else
        flash.now[:error] = "Problem updating message."
        format.xml  { render :xml  => @message.errors, :status => :unprocessable_entity }
        format.js   { render :json => @message.errors, :status => :unprocessable_entity }
      end
    end
  end

  # Delete multiple messages.
  def delete_messages
    id_list = params[:message_ids] || []
    if current_user.has_role?(:admin_user)
      message_list = Message.where(:id => id_list).all
    else
      message_list = current_user.messages.where(:id => id_list).all
    end
    deleted_count = 0

    message_list.each do |message_item|
      deleted_count += 1
      message_item.destroy
    end

    flash[:notice] = "#{view_pluralize(deleted_count, "item")} deleted.\n"
    redirect_to :action => :index
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

    head :ok
  end

  private

  def message_params
    params.require(:message).permit(:header, :description, :variable_text, :message_type, :read, :user_id, :expiry, :last_sent, :critical, :display, :send_email, :group_id, :sender_id)
  end
end
