
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

# RESTful controller for the CustomFilter resource.
class CustomFiltersController < ApplicationController

  before_filter :login_required
  layout false
  api_available

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def new #:nodoc:
    filter_param = "#{params[:filter_class]}".classify
    unless CustomFilter.descendants.map(&:name).include?(filter_param)
      cb_error "Filter class required", :status  => :unprocessable_entity
    end
    filter_class  = Class.const_get(filter_param)
    @custom_filter = filter_class.new
  end

  def edit #:nodoc:
    @custom_filter = current_user.custom_filters.find(params[:id])
  end

  # POST /custom_filters
  # POST /custom_filters.xml
  def create #:nodoc:
    filter_param = "#{params[:filter_class]}".classify
    unless CustomFilter.descendants.map(&:name).include?(filter_param)
      cb_error "Filter class required", :status  => :unprocessable_entity
    end
    params[:data] ||= {}

    filter_class  = Class.const_get(filter_param)
    @custom_filter = filter_class.new(params[:custom_filter])
    @custom_filter.data.merge! params[:data]

    @custom_filter.user_id = current_user.id

    @custom_filter.save

    if @custom_filter.errors.empty?
      flash[:notice] = "Filter successfully created."
    end

  end

  # PUT /custom_filters/1
  # PUT /custom_filters/1.xml
  def update #:nodoc:
    @custom_filter = current_user.custom_filters.find(params[:id])

    params[:custom_filter] ||= {}
    params[:data] ||= {}

    params[:custom_filter].each{|k,v| @custom_filter.send("#{k}=", v)}
    @custom_filter.data.merge! params[:data]

    @custom_filter.save

    if @custom_filter.errors.empty?
      flash[:notice] = "Custom filter '#{@custom_filter.name}' was successfully updated."
      return
    end


    respond_to do |format|
      format.xml  { render :xml => @custom_filter.errors, :status => :unprocessable_entity }
      format.js
    end
  end

  # DELETE /custom_filters/1
  # DELETE /custom_filters/1.xml
  def destroy #:nodoc:
    @custom_filter = current_user.custom_filters.find(params[:id])
    @custom_filter.destroy

    flash[:notice] = "Custom filter '#{@custom_filter.name}' deleted."

    respond_to do |format|
      format.js
      format.xml  { head :ok }
    end
  end
end
