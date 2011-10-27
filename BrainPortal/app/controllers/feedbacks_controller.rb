
#
# CBRAIN Project
#
# Controller for the user feedback resource.
#
# Original author: Tarek Sherif
#
# $Id$
#

#RESTful controller for the Feedback resource.
class FeedbacksController < ApplicationController
  before_filter :login_required
  
  Revision_info=CbrainFileRevision[__FILE__]
  
  # GET /feedbacks
  # GET /feedbacks.xml
  def index #:nodoc:
    @filter_params["sort_hash"]["order"] ||= 'feedbacks.created_at'
    @filter_params["sort_hash"]["dir"] ||= 'DESC'
    
    @feedbacks = base_filtered_scope
    @feedbacks = @feedbacks.includes(:user)

    respond_to do |format|
      format.js
      format.html # index.html.erb
      format.xml  { render :xml => @feedbacks }
    end
  end

  # GET /feedbacks/1
  # GET /feedbacks/1.xml
  def show #:nodoc:
    @feedback = Feedback.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @feedback }
    end
  end

  def new #:nodoc:
    @feedback = Feedback.new
    render :partial => "new"
  end
   
  # GET /feedbacks/1/edit
  def edit #:nodoc:
    @feedback = Feedback.find(params[:id])
  end

  # POST /feedbacks
  # POST /feedbacks.xml
  def create #:nodoc:
    @feedback = Feedback.new(params[:feedback])
    @feedback.user_id = current_user.id

    respond_to do |format|
      if @feedback.save
        flash[:notice] = 'Feedback was successfully created.'
        Message.send_message( User.all_admins, {
                              :message_type   => :notice,
                              :header         => "New feeback is available!",
                              :description    => nil,
                              :variable_text  => "#{current_user.full_name} : [[View][/feedbacks/#{@feedback.id}]]"
                              }
                            )
        format.js  { redirect_to :action => :index, :format => :js }
        format.xml { render :xml => @feedback, :status => :created, :location => @feedback }
      else
        format.js  { render :partial  => 'shared/failed_create', :locals  => {:model_name  => 'feedback' } }
        format.xml { render :xml => @feedback.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /feedbacks/1
  # PUT /feedbacks/1.xml
  def update #:nodoc:
    @feedback = Feedback.find(params[:id])

    respond_to do |format|
      if @feedback.update_attributes(params[:feedback])
        flash[:notice] = 'Feedback was successfully updated.'
        format.html { redirect_to feedbacks_path }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @feedback.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /feedbacks/1
  # DELETE /feedbacks/1.xml
  def destroy #:nodoc:
    @feedback = Feedback.find(params[:id])
    @feedback.destroy
    
    respond_to do |format|
      format.html { redirect_to(feedbacks_url) }
      format.js   { redirect_to :action => :index, :format => :js }
      format.xml  { head :ok }
    end
  end
end
