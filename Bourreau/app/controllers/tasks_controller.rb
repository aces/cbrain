
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
# $Id$
#

class TasksController < ApplicationController

  Revision_info="$Id$"

  before_filter :find_or_initialize_task, :except => [ :index, :ping ]

  # GET /tasks
  # Formats: xml
  def index
    if params[:user_id]
      @tasks = DrmaaTask.find(:all, :conditions => { :cluster_name => CBRAIN_CLUSTERS::BOURREAU_CLUSTER_NAME, :user_id => params[:user_id]} ) || []
    else
      @tasks = DrmaaTask.find(:all, :conditions => { :cluster_name => CBRAIN_CLUSTERS::BOURREAU_CLUSTER_NAME } ) || []
    end
    @tasks = [ @tasks ] unless @tasks.is_a?(Array)
    @tasks.each { |t| t.update_status }
    #puts @tasks.to_xml( :root => "DrmaaTasks" )
    respond_to do |format|
      format.html { head :method_not_allowed }
      
      format.xml { render :xml => @tasks.to_xml }
    end
  end

  # POST /tasks
  # Formats: xml
  def create
    respond_to do |format|
      format.html { head :method_not_allowed }
      
      if @task.start_all # this saves an preliminary object which we get here
        format.xml do
          headers['Location'] = url_for(:controller => "drmaa_tasks", :action => nil, :id => @task.id)
          render :xml => @task.to_xml, :status => :created
        end
      else
        format.xml { render :xml => @task.errors.to_xml, :status => :unprocessable_entity }
      end
    end
  end
  
  # GET /tasks/<id>
  # Formats: xml
  def show
    @task.capture_job_out_err
    respond_to do |format|
      format.html { head :method_not_allowed }
      format.xml { render :xml => @task }
    end
  end
  
  # PUT /tasks/<id>
  # Formats: xml
  # The only update operation we allow is to the 'status'
  # attribute; based on the previous value of status,
  # this will trigger some method calls to control the task
  def update
    respond_to do |format|
      format.html { head :method_not_allowed }

      oldstatus   = @task.status

      # Find the hash table where ActiveResource supply the new attributes
      uncameltask = @task.uncamelize
      newparams   = params[uncameltask]
      newstatus   = newparams['status']

      # This action triggers postprocessing, changing from "Data Ready" to "Completed"
      @task.post_process if newstatus == "postprocess" && oldstatus == "Data Ready"

      # These actions trigger DRMAA task control actions
      # They will update the "status" field depending on the action's result
      @task.suspend      if newstatus == "Suspended"
      @task.resume       if newstatus == "On CPU"
      @task.hold         if newstatus == "On Hold"
      @task.release      if newstatus == "Queued"
      @task.terminate    if newstatus == "Terminated"

      #if @task.update_attributes(params[@task.uncamelize])
      if @task.save
        format.xml { render :xml => @task.to_xml }
      else
        format.xml { render :xml => @task.errors.to_xml, :status => :unprocessable_entity }
      end
    end
  end
  
  # DELETE /tasks/<id>
  # Formats: xml
  def destroy
    respond_to do |format|
      format.html { head :method_not_allowed }
      
      if @task.destroy
        format.xml { head :ok }
      else
        format.xml { render :xml => @task.errors.to_xml, :status => :unprocessable_entity }
      end
    end
  end
  
  def find_or_initialize_task
    if params[:id]
      if @task = DrmaaTask.find_by_id(params[:id], :conditions => { :cluster_name => CBRAIN_CLUSTERS::BOURREAU_CLUSTER_NAME } )
        @task.update_status
      else
        render_optional_error_file :not_found
      end
    else
      # This is all fuzzy logic trying to figure out the
      # expected real class for the new object, based on
      # the content of the keys and values of params
      subtypes = params.keys.select { |x| x =~ /^drmaa_/i }
      subtypekey  = subtypes[0] # hopefully just one
      if subtypekey && subtypehash = params[subtypes[0]]
        subtype  = subtypehash[:type]
      end
      if !subtype && subtypekey # try another way
        subtype = subtypekey.camelize.sub(/^drmaa_/i,"Drmaa")
      end
      @task = Class.const_get(subtype).new(subtypehash)
    end
  end

  # GET /ping
  def ping
    @message = DrmaaTask.ping
    respond_to do |format|
      format.html { render :action => 'ping' }
      format.xml  { render :xml => { :message => @message } }
    end
  end
  
end
