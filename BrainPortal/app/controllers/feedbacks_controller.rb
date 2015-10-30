
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

#RESTful controller for the Feedback resource.
class FeedbacksController < ApplicationController
  before_filter :login_required

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # GET /feedbacks
  # GET /feedbacks.xml
  def index #:nodoc:
    @scope = scope_from_session('feedbacks')
    scope_default_order(@scope, 'created_at', :desc)

    @base_scope = Feedback.includes(:user)
    @feedbacks  = @scope.apply(@base_scope)

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
                              :header         => "New feedback is available!",
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
      if @feedback.update_attributes_with_logging(params[:feedback], current_user, %w( summary details ))
        flash[:notice] = 'Feedback was successfully updated.'
        format.html { redirect_to :action => "show" }
        format.xml  { head :ok }
      else
        @feedback.reload
        format.html { render :action => "show" }
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
      format.html { redirect_to :action => :index, :status => 303 }
      format.js   { redirect_to :action => :index, :format => :js, :status => 303 }
      format.xml  { head :ok }
    end
  end
end
