
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
  def index
    @messages = current_user.messages.all(:order  => "last_sent DESC")

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @messages }
    end
  end

  # GET /messages/1
  # GET /messages/1.xml
  def show
    @message = Message.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @message }
    end
  end

  # GET /messages/new
  # GET /messages/new.xml
  # def new
  #    @message = Message.new
  # 
  #    respond_to do |format|
  #      format.html # new.html.erb
  #      format.xml  { render :xml => @message }
  #    end
  #  end

  # GET /messages/1/edit
  # def edit
  #     @message = Message.find(params[:id])
  #   end

  # POST /messages
  # POST /messages.xml
  def create
    @message = Message.new(params[:message])
    
    @message.send_me_to(Group.find(params[:groups][:group_id]))

    respond_to do |format|
      flash[:notice] = 'Message was successfully sent.'
      format.xml  { render :xml => @message, :status => :created, :location => @message }
      
      format.js do
        @messages = current_user.messages.all(:order  => "last_sent DESC")
        prepare_messages
        
        render :update do |page|
            @message = Message.new
            page['new_message'].replace_html(:partial  => 'new').hide
            page.replace_html :message_display, :partial  => 'layouts/message_display'
            page.replace_html :message_table,   :partial  => 'message_table'
        end
      end
    end
  end

  # PUT /messages/1
  # PUT /messages/1.xml
  def update
    @message = current_user.messages.find(params[:id])

    respond_to do |format|
      if @message.update_attributes(:read  => params[:read])
        format.xml  { head :ok }
      else
        flash.now[:error] = "Problem updating message."
        format.xml  { render :xml => @message.errors, :status => :unprocessable_entity }
      end
      format.js do
        @messages = current_user.messages.all(:order  => "last_sent DESC")
        prepare_messages
        render :update do |page|
          page.replace_html :message_display, :partial  => 'layouts/message_display'
            page << "if($('message_table')){"
            page.replace_html :message_table,   :partial  => 'message_table'
            page << "}"        
          end
      end
    end
  end

  # DELETE /messages/1
  # DELETE /messages/1.xml
  def destroy
    @message = current_user.messages.find(params[:id])
    unless @message.destroy
      flash.now[:error] = "Could not delete message."
    end
    @messages = current_user.messages.all(:order  => "last_sent DESC")
    prepare_messages
    
    respond_to do |format|
      format.js do
        render :update do |page|
          page.replace_html :message_display, :partial  => 'layouts/message_display'
          page << "if($('message_table')){"
          page.replace_html :message_table,   :partial  => 'message_table'
          page << "}"
        end
      end
      format.xml  { head :ok }
    end
  end
end
