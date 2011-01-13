
#
# CBRAIN Project
#
# RESTful Custom filters Controller
#
# Original author: Tarek Sherif
#
# $Id$
#

#RESTful controller for the CustomFilter resource.
class CustomFiltersController < ApplicationController
  
  before_filter :login_required
  
  api_available
  
  Revision_info="$Id$"

  # POST /custom_filters
  # POST /custom_filters.xml
  def create #:nodoc:
    if params[:filter_class].blank?
      cb_error "Filter class required", :status  => :unprocessable_entity
    end
    params[:data] ||= {}
    
    filter_class  = Class.const_get("#{params[:filter_class]}".classify)
    @custom_filter = filter_class.new(params[:custom_filter])
    @custom_filter.data.merge! params[:data]
    
    @custom_filter.user_id = current_user.id
    
    respond_to do |format|
      if @custom_filter.save
        flash[:notice] = "Custom filter '#{@custom_filter.name}' was successfully created."
        format.xml  { render :xml => @custom_filter }
      else
        format.xml  { render :xml => @custom_filter.errors, :status => :unprocessable_entity }
      end
      format.js  
    end
  end

  # PUT /custom_filters/1
  # PUT /custom_filters/1.xml
  def update #:nodoc:
    @custom_filter = current_user.custom_filters.find(params[:id])
    filter_name = @custom_filter.name
    
    params[:custom_filter] ||= {}
    params[:data] ||= {}
    
    params[:custom_filter].each{|k,v| @custom_filter.send("#{k}=", v)}
    @custom_filter.data.merge! params[:data]
    
    respond_to do |format|
      if @custom_filter.save
        flash[:notice] = "Custom filter '#{@custom_filter.name}' was successfully updated."
        if @custom_filter.filtered_class_controller == "userfiles"    
          if current_session.userfiles_custom_filters.include?(filter_name)
            current_session.userfiles_custom_filters.delete filter_name
            current_session.userfiles_custom_filters << @custom_filter.name
          end
        end
        format.xml  { head :ok }
      else        
        format.xml  { render :xml => @custom_filter.errors, :status => :unprocessable_entity }
      end
      format.js
    end
  end

  # DELETE /custom_filters/1
  # DELETE /custom_filters/1.xml
  def destroy #:nodoc:
    @custom_filter = current_user.custom_filters.find(params[:id])
    if @custom_filter.filtered_class_controller == "userfiles"    
      current_session.userfiles_custom_filters.delete @custom_filter.name
    else
      current_session[@custom_filter.filtered_class_controller.to_sym]["filters"].delete "custom_filter"
    end
    @custom_filter.destroy

    flash[:notice] = "Custom filter '#{@custom_filter.name}' deleted."

    respond_to do |format|
      format.js
      format.xml  { head :ok }
    end
  end
end
