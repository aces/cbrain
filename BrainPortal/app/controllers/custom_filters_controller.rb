
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
  
  Revision_info="$Id$"

  # GET /custom_filters/new
  # GET /custom_filters/new.xml
  def new #:nodoc:
    filter_class  = Class.const_get("#{params[:type]}_custom_filter".classify)
    @custom_filter = filter_class.new
    @user_groups   = current_user.groups
    @user_tags   = current_user.tags

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @custom_filter }
    end
  end

  # GET /custom_filters/1/edit
  def edit #:nodoc:
    @custom_filter = current_user.custom_filters.find(params[:id])
    @user_groups   = current_user.groups
    @user_tags   = current_user.tags
  end

  # POST /custom_filters
  # POST /custom_filters.xml
  def create #:nodoc:
    filter_class  = Class.const_get("#{params[:type]}_custom_filter".classify)
    @custom_filter = filter_class.new(params[:custom_filter])
    @custom_filter.data = params[:data]
    
    @custom_filter.user_id = current_user.id
        
    respond_to do |format|
      if @custom_filter.save
        flash[:notice] = "Custom filter '#{@custom_filter.name}' was successfully created."
        format.html { redirect_to(:controller  => @custom_filter.filtered_class_controller, :action  => :index) }
        format.xml  { render :xml => @custom_filter, :status => :created, :location => @custom_filter }
      else
        @user_groups   = current_user.groups  
        @user_tags   = current_user.tags
              
        format.html { render :action => "new" }
        format.xml  { render :xml => @custom_filter.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /custom_filters/1
  # PUT /custom_filters/1.xml
  def update #:nodoc:
    @custom_filter = current_user.custom_filters.find(params[:id])
    filter_name = @custom_filter.name
    
    params[:custom_filter].each{|k,v| @custom_filter.send("#{k}=", v)}
    @custom_filter.data = params[:data]
    
    respond_to do |format|
      if @custom_filter.save
        flash[:notice] = "Custom filter '#{@custom_filter.name}' was successfully updated."
        if @custom_filter.filtered_class_controller == "userfiles"    
          if current_session.userfiles_custom_filters.include?(filter_name)
            current_session.userfiles_custom_filters.delete filter_name
            current_session.userfiles_custom_filters << @custom_filter.name
          end
        end
        format.html { redirect_to(:controller  => @custom_filter.filtered_class_controller, :action  => :index) }
        format.xml  { head :ok }
      else
        @user_groups   = current_user.groups
        @user_tags   = current_user.tags
        
        format.html { render :action => "edit" }
        format.xml  { render :xml => @custom_filter.errors, :status => :unprocessable_entity }
      end
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
      format.html { redirect_to(:controller  => @custom_filter.filtered_class_controller, :action  => :index) }
      format.xml  { head :ok }
    end
  end
end
