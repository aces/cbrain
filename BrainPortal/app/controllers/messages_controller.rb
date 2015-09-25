
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

  before_filter :login_required
  before_filter :manager_role_required, :only  => :create

  # GET /messages
  # GET /messages.xml
  def index #:nodoc:
    @scope = scope_from_session('messages')
    scope_default_order(@scope, 'last_sent', :desc)

    @base_scope = Message
    @base_scope = @base_scope.where(:user_id => current_user.available_users.map(&:id)) unless
      current_user.has_role?(:admin_user)
    @view_scope = @messages = @scope.apply(@base_scope)

    @read_count   = @view_scope.where(:read => true).count
    @unread_count = @view_scope.count - @read_count

    @scope.pagination ||= Scope::Pagination.from_hash({ :per_page => 25 })
    @messages = @scope.pagination.apply(@view_scope)

    scope_to_session(@scope)
    current_session.save_preferences

    respond_to do |format|
      format.html # index.html.erb
      format.js
      format.xml  { render :xml => @messages }
    end
  end

  def new #:nodoc:
    @message  = Message.new # blank object for new() form.
    @group_id = nil         # for new() form
    render :partial => "new"
  end

  # POST /messages
  # POST /messages.xml
  def create #:nodoc:
    @message = Message.new(params[:message])

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

    @group_id = params[:group_id]
    if @group_id.blank?
      @message.errors.add(:base, "You need to specify the project whose members will receive this message.")
    elsif @message.errors.empty?
      group = current_user.available_groups.find(@group_id)
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
        format.xml { render :xml => @message, :status => :created, :location => @message }
        format.js  { redirect_to :action => :index }
      else
        format.xml { render :xml => @message.errors, :status => :unprocessable_entity }
        format.js  {  render :partial  => 'shared/failed_create', :locals  => {:model_name  => 'message' } }
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

    respond_to do |format|
      if @message.update_attributes(:read  => params[:read])
        format.xml  { head :ok }
      else
        flash.now[:error] = "Problem updating message."
        format.xml  { render :xml => @message.errors, :status => :unprocessable_entity }
      end
      format.js do
        redirect_to :action => :index
      end
    end
  end

  # Delete multiple messages.
  def delete_messages
    id_list = params[:message_ids] || []
    if current_user.has_role?(:admin_user)
      message_list = Message.find(id_list)
    else
      message_list = current_user.messages.find(id_list)
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
      @message = Message.find(params[:id])
    else
      @message = current_user.messages.find(params[:id])
    end
    unless @message.destroy
      flash.now[:error] = "Could not delete message."
    end

    head :ok
  end

end
