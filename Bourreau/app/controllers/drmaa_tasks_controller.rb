#
# CBRAIN Project
#
# RESTful ActiveResource Controller for DRMAA_Tasks
#
# Original code provided by Jade Meskill, blog owner of
# http://iamruinous.com/2007/10/01/creating-an-activeresource-compatible-controller/
# Obtained his permission on October 27th, 2008.
#
# Modified by Pierre Rioux
#
# $Id: drmaatask_controller.rb 31 2008-10-31 14:50:32Z prioux $
#

class DRMAATasksController < ApplicationController

  Revision_info="$Id: drmaatask_controller.rb 31 2008-10-31 14:50:32Z prioux $"

  before_filter :find_or_initialize_drmaatask, :except => [ :index ]

  # GET /drmaatasks
  # Formats: xml
  def index
    @drmaatasks = DRMAATask.find(:all)
    respond_to do |format|
      format.html { head :method_not_allowed }
      
      format.xml { render :xml => @drmaatasks.to_xml }
    end
  end

  # POST /drmaatasks
  # Formats: xml
  def create
    respond_to do |format|
      format.html { head :method_not_allowed }
      
      if @drmaatask.save
        format.xml { headers['Location'] = drmaatask_url(@drmaatask); render :xml => @drmaatask.to_xml, :status => :created }
      else
        format.xml { render :xml => @drmaatask.errors.to_xml, :status => :unprocessable_entity }
      end
    end
  end
  
  # GET /drmaatasks/<id>
  # Formats: xml
  def show
    respond_to do |format|
      format.html { head :method_not_allowed }
      format.xml { render :xml => @drmaatask }
    end
  end
  
  # PUT /drmaatasks/<id>
  # Formats: xml
  def update
    respond_to do |format|
      format.html { head :method_not_allowed }

      if @drmaatask.update_attributes(params[:drmaatask])
        format.xml { render :xml => @drmaatask.to_xml }
      else
        format.xml { render :xml => @drmaatask.errors.to_xml, :status => :unprocessable_entity }
      end
    end
  end
  
  # DELETE /drmaatasks/<id>
  # Formats: xml
  def destroy
    respond_to do |format|
      format.html { head :method_not_allowed }
      
      if @drmaatask.destroy
        format.xml { head :ok }
      else
        format.xml { render :xml => @drmaatask.errors.to_xml, :status => :unprocessable_entity }
      end
    end
  end
  
  def find_or_initialize_drmaatask
    if params[:id]
      unless @drmaatask = DRMAATask.find_by_id(params[:id])
        render_optional_error_file :not_found
      end
    else
      @drmaatask         = DRMAATask.new(params[:drmaatask])
    end
  end
  
end
