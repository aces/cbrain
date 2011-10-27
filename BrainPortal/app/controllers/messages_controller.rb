
#
# CBRAIN Project
#
# Messages controller for the BrainPortal interface
#
# Original author: Pierre Rioux
#
# $Id$
#

# RESTful controller for managing Messages.
class MessagesController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__]

  before_filter :login_required
  before_filter :manager_role_required, :only  => :create

  # GET /messages
  # GET /messages.xml
  def index #:nodoc:
    @show_users = false
    @max_show   = "50"

    scope = base_filtered_scope
    if current_user.has_role?(:admin)
      user_id      = params[:user_id]      ||= current_user.id.to_s
      upd_before   = params[:upd_before]   ||= "0"
      upd_after    = params[:upd_after]    ||= 50.years.to_s
      message_type = params[:message_type] ||= ""
      critical     = params[:critical]     ||= ""
      read         = params[:read]         ||= ""
      @max_show    = params[:max_show]     ||= 50.to_s
      if (params[:commit] || "") =~ /Apply/i
        @show_users = user_id.blank? || user_id != current_user.id.to_s
        if user_id =~ /^\d+$/
          scope = scope.scoped( :conditions => { :user_id => user_id.to_i } )
        end
        bef = upd_before.to_i
        aft = upd_after.to_i
        bef,aft = aft,bef if aft < bef
        bef = bef < 1 ? 1.day.from_now : bef.ago
        aft = aft.ago
        scope = scope.scoped( :conditions => [ "messages.last_sent < TIMESTAMP(?) AND messages.last_sent > TIMESTAMP(?)", bef, aft ] )
        if message_type =~ /^[a-z]+$/
          scope = scope.scoped( :conditions => { :message_type => message_type } )
        end
        unless critical.blank?
          scope = scope.scoped( :conditions => { :critical => (critical == '1') } )
        end
        unless read.blank?
          scope = scope.scoped( :conditions => { :read => (read == '1') } )
        end
      else
        scope = scope.scoped( :conditions => { :user_id => current_user.id } )
      end
    else
      scope = scope.scoped(:conditions => {:user_id => current_user.id})
    end
    @messages = scope.order( "last_sent DESC" )
    
    respond_to do |format|
      format.html # index.html.erb
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
      flash.now[:notice] = 'Message was successfully sent.'
      format.xml  { render :xml => @message, :status => :created, :location => @message }
      
      format.js do
        @messages = current_user.messages.order( "last_sent DESC" )
        
        render :action  => :create
      end
    end
  end

  # PUT /messages/1
  # PUT /messages/1.xml
  def update #:nodoc:
    if current_user.has_role? :admin
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
        prepare_messages
        @messages = current_user.messages.order( "last_sent DESC" )
         render :action  => "update_tables"
      end
    end
  end

  # Delete multiple messages.
  def delete_messages #:nodoc:
    message_list = params[:message_ids] || []
    deleted_count = 0
    
    message_list.each do |message_item|
      message_obj = Message.find(message_item)
      deleted_count += 1
      message_obj.destroy
    end
    
    flash[:notice] = "#{view_pluralize(deleted_count, "items")} deleted.\n" 
    redirect_to :action => :index
  end

  # DELETE /messages/1
  # DELETE /messages/1.xml
  def destroy #:nodoc:
    @message = current_user.messages.find(params[:id])
    unless @message.destroy
      flash.now[:error] = "Could not delete message."
    end
    prepare_messages
    @messages = current_user.messages.order( "last_sent DESC" )
    
    respond_to do |format|
      format.js { render :action  => "update_tables" }
      format.xml  { head :ok }
    end
  end

end
