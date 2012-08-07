
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

  before_filter :login_required
  layout false

  def new
    @tag = Tag.new(:group_id => current_user.own_group.id)
  end

  # GET /tags/1/edit
  def edit #:nodoc:
    @tag = current_user.tags.find(params[:id])
  end

  # POST /tags
  # POST /tags.xml
  def create #:nodoc:
    @tag = Tag.new(params[:tag])
    @tag.user_id = current_user.id

    respond_to do |format|
      if @tag.save
        flash[:notice] = 'Tag was successfully created.'
        format.html { redirect_to userfiles_path }        
        format.xml  { render :xml => @tag, :status => :created, :location => @tag }
      else
        format.html { redirect_to userfiles_path }
        format.xml  { render :xml => @tag.errors, :status => :unprocessable_entity }
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
        format.html { redirect_to userfiles_path }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @tag.errors, :status => :unprocessable_entity }
      end
      format.js
    end
  end

  # DELETE /tags/1
  # DELETE /tags/1.xml
  def destroy #:nodoc:
    @tag = current_user.tags.find(params[:id])
    if current_session[:userfiles]["filter_tags_array"]
      current_session[:userfiles]["filter_tags_array"].delete @tag.id.to_s
    end
    @tag.destroy

    respond_to do |format|
      format.html { redirect_to userfiles_path }
      format.js {render :partial  => "update_tag_table"}
      format.xml  { head :ok }
    end
  end
end
