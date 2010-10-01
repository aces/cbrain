
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

  Revision_info="$Id$"

  before_filter :login_required
  before_filter :manager_role_required, :only  => :create
  # GET /messages
  # GET /messages.xml
  def index #:nodoc:
    @messages = current_user.messages.all(:order  => "last_sent DESC")
    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @messages }
    end
  end

  # POST /messages
  # POST /messages.xml
  def create #:nodoc:
    @message = Message.new(params[:message])
    @message.send_me_to(Group.find(params[:group_id]))
    prepare_messages

    respond_to do |format|
      flash.now[:notice] = 'Message was successfully sent.'
      format.xml  { render :xml => @message, :status => :created, :location => @message }
      
      format.js do
        @messages = current_user.messages.all(:order  => "last_sent DESC")
        
        render :action  => :create
      end
    end
  end

  # PUT /messages/1
  # PUT /messages/1.xml
  def update #:nodoc:
    @message = current_user.messages.find(params[:id])

    respond_to do |format|
      if @message.update_attributes(:read  => params[:read])
        format.xml  { head :ok }
      else
        flash.now[:error] = "Problem updating message."
        format.xml  { render :xml => @message.errors, :status => :unprocessable_entity }
      end
      format.js do
        prepare_messages
        @messages = current_user.messages.all(:order  => "last_sent DESC")
         render :action  => "update_tables"
      end
    end
  end
  
  #Delete multiple messages.
  def delete_messages #:nodoc:
    message_list = params[:message_ids] || []
    deleted_count = 0
    
    message_list.each do |message_item|
      message_obj = Message.find(message_item)
      deleted_count += 1
      message_obj.destroy
    end
    
    flash[:notice] = "#{@template.pluralize(deleted_count, "items")} deleted.\n" 
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
    @messages = current_user.messages.all(:order  => "last_sent DESC")
    
    respond_to do |format|
      format.js { render :action  => "update_tables" }
      format.xml  { head :ok }
    end
  end
end
