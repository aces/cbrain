
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
  # GET /messages
  # GET /messages.xml
  def index
    @messages = current_user.messages.all

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

    respond_to do |format|
      if @message.save
        flash[:notice] = 'Message was successfully created.'
        format.html { redirect_to(@message) }
        format.xml  { render :xml => @message, :status => :created, :location => @message }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @message.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /messages/1
  # PUT /messages/1.xml
  def update
    @message = current_user.messages.find(params[:id])

    respond_to do |format|
      if @message.update_attributes(:read  => params[:read])
        prepare_messages
        format.js
        format.xml  { head :ok }
      else
        flash.now[:error] = "Problem updating message."
        format.js
        format.xml  { render :xml => @message.errors, :status => :unprocessable_entity }
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
    prepare_messages
    
    respond_to do |format|
      format.js do
        render :update do |page|
          page[:message_display].replace_html :partial  => 'layouts/message_display'
        end
      end
      format.xml  { head :ok }
    end
  end
end
