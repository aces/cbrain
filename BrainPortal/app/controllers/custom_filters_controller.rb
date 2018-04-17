
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

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  api_available

  before_action :login_required

  def new #:nodoc:
    filter_param = "#{params[:filter_class]}".classify
    unless CustomFilter.descendants.map(&:name).include?(filter_param)
      cb_error "Filter class required", :status  => :unprocessable_entity
    end
    filter_class  = Class.const_get(filter_param)
    @custom_filter = filter_class.new
  end

  def show #:nodoc:
    @custom_filter = current_user.custom_filters.find(params[:id])
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

    filter_class   = Class.const_get(filter_param)
    @custom_filter = filter_class.new(custom_filter_params(filter_class))

    @custom_filter.user_id = current_user.id


    if @custom_filter.errors.empty?
      flash[:notice] = "Filter successfully created."
    end

    respond_to do |format|
      if @custom_filter.save
        flash[:notice] = 'Filter successfully created.'
        format.html { redirect_to :controller => controller_name(), :action => :index }
      else
        format.html { render :action  => :new }
      end
    end

  end

  # PUT /custom_filters/1
  # PUT /custom_filters/1.xml
  def update #:nodoc:
    @custom_filter = current_user.custom_filters.find(params[:id])

    custom_filter_params(@custom_filter.class).each{|k,v| @custom_filter.send("#{k}=", v)}

    params[:data]        ||= {}
    @custom_filter.data.merge! params[:data]

    @custom_filter.save

    respond_to do |format|
      if @custom_filter.errors.empty?
        flash[:notice] = "Custom filter '#{@custom_filter.name}' was successfully updated."
        format.html { render :action => :show }
      else
        @custom_filter.reload
        format.html { render :action => :show }
        format.xml  { render :xml  => @custom_filter.errors, :status => :unprocessable_entity }
        format.js
      end
    end
  end

  # DELETE /custom_filters/1
  # DELETE /custom_filters/1.xml
  def destroy #:nodoc:
    @custom_filter = current_user.custom_filters.find(params[:id])
    @custom_filter.destroy

    flash[:notice] = "Custom filter '#{@custom_filter.name}' deleted."

    respond_to do |format|
      format.html { redirect_to :controller => controller_name(), :action => :index }
      format.js
      format.xml  { head :ok }
    end
  end

  private

  def custom_filter_params(filter_class) #:nodoc:
    custom_filter_attr = params.require(:custom_filter).permit(:name, :user_id)

    # A way to allow arbitrary value in data
    data_allowed_keys  = filter_class::DATA_PARAMS
    custom_filter_data = params.require(:data).permit(data_allowed_keys)
    custom_filter_attr[:data] = custom_filter_data
    custom_filter_attr
  end

  def controller_name
    @custom_filter.type.gsub(/CustomFilter$/, "").downcase.pluralize.to_sym
  end

end
