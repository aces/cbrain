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

  before_action :login_required

  # GET /tags
  # GET /tags.xml
  # GET /tags.json
  def index #:nodoc:
    @tags = current_user.tags.all
    respond_to do |format|
      format.xml  { render :xml  => @tags.to_a.for_api }
      format.json { render :json => @tags.to_a.for_api }
    end
  end

  # GET /tags/1
  # GET /tags/1.xml
  # GET /tags/1.json
  def show #:nodoc:
    @tag = current_user.tags.find(params[:id])
    respond_to do |format|
      format.xml  { render :xml  => @tag.for_api }
      format.json { render :json => @tag.for_api }
    end
  end

  # POST /tags
  # POST /tags.xml
  # POST /tags.json
  def create #:nodoc:
    @tag = Tag.new(tag_params)

    respond_to do |format|
      if @tag.save
        flash[:notice] = 'Tag was successfully created.'
        format.xml  { render :xml  => @tag.for_api, :status => :created, :location => @tag }
        format.json { render :json => @tag.for_api, :status => :created, :location => @tag }
      else
        format.xml  { render :xml  => @tag.errors, :status => :unprocessable_entity }
        format.json { render :json => @tag.errors, :status => :unprocessable_entity }
      end
      format.js
    end
  end

  # PUT /tags/1
  # PUT /tags/1.xml
  # PUT /tags/1.json
  def update #:nodoc:
    @tag = current_user.tags.find(params[:id])

    respond_to do |format|
      if @tag.update_attributes(tag_params)
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
  # DELETE /tags/1.json
  def destroy #:nodoc:
    @tag = current_user.tags.find(params[:id])
    @tag.destroy

    respond_to do |format|
      format.xml  { head :ok, :content_type => 'text/plain' }
      format.json { head :ok, :content_type => 'text/plain' }
    end
  end

  private

  def tag_params #:nodoc:
    new_tag_attr = params.require(:tag).permit(:name, :user_id, :group_id)

    # Adjusts user_id and group_id to make sure they stay within allowed values
    user_id      = new_tag_attr[:user_id]
    group_id     = new_tag_attr[:group_id]
    new_tag_attr[:user_id]  = current_user.id           if !current_user.available_users.where(:id => user_id).exists?
    new_tag_attr[:group_id] = current_user.own_group.id if !current_user.available_groups.where(:id => group_id).exists?

    new_tag_attr
  end

end
