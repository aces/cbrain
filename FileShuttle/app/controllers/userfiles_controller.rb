
#
# CBRAIN Project
#
# RESTful ActiveResource Controller for Userfiles
#
# Original code provided by Jade Meskill, blog owner of
# http://iamruinous.com/2007/10/01/creating-an-activeresource-compatible-controller/
# Obtained his permission on October 27th, 2008.
#
# Modified by Pierre Rioux
#
# $Id$
#

class UserfilesController < ApplicationController

  Revision_info="$Id$"

  before_filter :find_or_initialize_userfile, :except => [ :index ]

  # GET /userfiles
  # Formats: xml
  def index
    @userfiles = Userfile.find(:all)
    respond_to do |format|
      format.html { head :method_not_allowed }
      
      format.xml { render :xml => @userfiles.to_xml }
    end
  end

  # POST /userfiles
  # Formats: xml
  def create
    respond_to do |format|
      format.html { head :method_not_allowed }
      
      if @userfile.save
        format.xml { headers['Location'] = userfile_url(@userfile); render :xml => @userfile.to_xml, :status => :created }
      else
        format.xml { render :xml => @userfile.errors.to_xml, :status => :unprocessable_entity }
      end
    end
  end
  
  # GET /userfiles/<id>
  # Formats: xml
  def show
    respond_to do |format|
      format.html { head :method_not_allowed }
      format.xml { render :xml => @userfile }
    end
  end
  
  # PUT /userfiles/<id>
  # Formats: xml
  def update
    respond_to do |format|
      format.html { head :method_not_allowed }

      if @userfile.update_attributes(params[:userfile])
        format.xml { render :xml => @userfile.to_xml }
      else
        format.xml { render :xml => @userfile.errors.to_xml, :status => :unprocessable_entity }
      end
    end
  end
  
  # DELETE /userfiles/<id>
  # Formats: xml
  def destroy
    respond_to do |format|
      format.html { head :method_not_allowed }
      
      if @userfile.destroy
        format.xml { head :ok }
      else
        format.xml { render :xml => @userfile.errors.to_xml, :status => :unprocessable_entity }
      end
    end
  end
  
  def find_or_initialize_userfile
    if params[:id]
      unless @userfile = Userfile.find_by_id(params[:id])
        render_optional_error_file :not_found
      end
      @userfile.read_content   # will load it from disk
    else
      @userfile         = Userfile.new(params[:userfile])
      @userfile.content = params[:content] if params[:content]
    end
  end
  
end
