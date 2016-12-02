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

#RESTful controller for the Tag resource.
class TagsController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  api_available :only => [ :index, :show, :update, :destroy, :create ]

  before_filter :login_required
  before_filter :validate_params, :only => [:update, :create]

  # GET /tags
  # GET /tags.xml
  def index #:nodoc:
    respond_to do |format|
      format.xml  { render :xml  => current_user.tags }
      format.json { render :json => current_user.tags.as_json }
    end
  end

  # GET /tags/1
  # GET /tags/1.xml
  def show #:nodoc:
    respond_to do |format|
      format.xml  { render :xml  => current_user.tags.find(params[:id]) }
      format.json { render :json => current_user.tags.find(params[:id]) }
    end
  end

  # POST /tags
  # POST /tags.xml
  def create #:nodoc:
    @tag = Tag.new(params[:tag])

    respond_to do |format|
      if @tag.save
        flash[:notice] = 'Tag was successfully created.'
        format.xml  { render :xml  => @tag, :status => :created, :location => @tag }
        format.json { render :json => @tag, :status => :created, :location => @tag }
      else
        format.xml  { render :xml  => @tag.errors, :status => :unprocessable_entity }
        format.json { render :json => @tag.errors, :status => :unprocessable_entity }
      end
      format.js
    end
  end

  # PUT /tags/1
  # PUT /tags/1.xml
  def update #:nodoc:
    @tag = current_user.tags.find(params[:id])

    respond_to do |format|
      if @tag.update_attributes(params[:tag])
        flash[:notice] = 'Tag was successfully updated.'
        format.xml  { head :ok, :content_type => 'text/plain' }
        format.json { head :ok }
      else
        format.xml  { render :xml  => @tag.errors, :status => :unprocessable_entity }
        format.json { render :json => @tag.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /tags/1
  # DELETE /tags/1.xml
  def destroy #:nodoc:
    @tag = current_user.tags.find(params[:id])
    @tag.destroy

    respond_to do |format|
      format.xml  { head :ok, :content_type => 'text/plain' }
      format.json { head :ok, :content_type => 'text/plain' }
    end
  end

  private

  # This method validates that the current user has access to the user and group being assigned to the created or updated tag
  def validate_params #:nodoc:
    user_id = params[:tag][:user_id]
    group_id = params[:tag][:group_id]

    params[:tag][:user_id]  = current_user.id           if !current_user.available_users.raw_first_column(:id).include?(user_id.to_i)
    params[:tag][:group_id] = current_user.own_group.id if !current_user.available_groups.raw_first_column(:id).include?(group_id.to_i)
  end

end
