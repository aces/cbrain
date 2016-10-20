
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

# RESTful controller for documentation resources
class HelpDocumentsController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  api_available :only => [ :index, :new, :create, :show, :destroy , :update]

  before_filter :login_required
  before_filter :core_admin_role_required, :except => :show

  # GET /docs
  def index #:nodoc:
    @docs = HelpDocument.order(:key)

    respond_to do |format|
      format.xml  { render :xml  => @docs }
      format.json { render :json => @docs }
    end
  end

  # GET /docs/1
  def show #:nodoc:
    @doc = HelpDocument.find_by_id(params[:id])

    respond_to do |format|
      format.json  { render :json => @doc.to_json(:methods => :contents) }
    end
  end

  def new #:nodoc:
    @doc = HelpDocument.new(:key => params[:key], :path => HelpDocument.path_from_key(params[:key]))

    # render :action => :show, :layout => false
    respond_to do |format|
      format.json   { render :json => @doc }
    end
  end

  # POST /docs
  def create #:nodoc:
    @doc            = HelpDocument.new(params[:doc])
    @doc.path     ||= HelpDocument.path_from_key(@doc.key)
    @doc.contents   = params[:contents]

    respond_to do |format|
      if @doc.save
        format.html { head   :created }
        format.xml  { render :xml  => @doc, :status => :created, :location => doc_url(@doc) }
        format.json { render :json => @doc, :status => :created, :location => doc_url(@doc) }
      else
        format.html { head   :unprocessable_entity }
        format.xml  { render :xml  => @doc.errors, :status => :unprocessable_entity }
        format.json { render :json => @doc.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /docs/1
  def update #:nodoc:
    @doc = HelpDocument.find(params[:id])

    if params.has_key?(:contents)
      @doc.contents = params[:contents] if params.has_key?(:contents)
      @doc.update_attribute(:updated_at, Time.now)
    end

    respond_to do |format|
      format.html { head   :ok }
      format.xml  { render :xml  => @doc.to_xml(:methods => :contents)  }
      format.json { render :json => @doc.to_json(:methods => :contents) }
    end
  end

  # DELETE /docs/1
  def destroy #:nodoc:
    @doc = HelpDocument.find_by_id(params[:id])
    @doc.destroy

    head :ok
  end
end
