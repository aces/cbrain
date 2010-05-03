
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

#RESTful controller for the DrmaaTask resource.
class TasksController < ApplicationController

  Revision_info="$Id$"
  
  before_filter :check_sender
  before_filter :find_or_initialize_task, :except => [ :index ]
  before_filter :start_workers

  # Index method no longer available.
  def index
    respond_to do |format|
      format.html { head :method_not_allowed }
      format.xml  { head :method_not_allowed }
    end
  end

  # POST /tasks
  # Formats: xml
  def create #:nodoc:
    respond_to do |format|
      format.html { head :method_not_allowed }
      
      @task.status = 'New'
      @task.adjust_prereqs_for_shared_tasks_wd
      if @task.save
        WorkerPool.find_pool(BourreauWorker).wake_up_workers
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
  def show #:nodoc:
    @task.capture_job_out_err
    respond_to do |format|
      format.html { head :method_not_allowed }
      format.xml { render :xml => @task }
    end
  end
  
  # PUT /tasks/<id>
  # Formats: xml
  
  # The only update operation we allow is to the 'status'
  # attribute. The status will be updated to the requested
  # status iff it is an allowable move from the 
  # previous state.
  def update
    respond_to do |format|
      format.html { head :method_not_allowed }

      # Find the hash table where ActiveResource supply the new attributes
      uncameltask = @task.uncamelize
      newparams   = params[uncameltask]
      newstatus   = newparams['status']

      # These actions trigger DRMAA task control actions
      # They will update the "status" field depending on the action's result
      @task.suspend      if newstatus == "Suspended"
      @task.resume       if newstatus == "On CPU"
      @task.hold         if newstatus == "On Hold"
      @task.release      if newstatus == "Queued"
      @task.terminate    if newstatus == "Terminated"

      # These actions trigger special handling code in the workers
      @task.recover                       if newstatus == "Recover"        # For 'Failed*' tasks
      @task.restart(Regexp.last_match[1]) if newstatus =~ /^Restart (\S+)/ # For 'Completed' tasks only

      # The 'Duplicate' operation copies the task object into a brand new task.
      # As a side effect, the task can be reassigned to another Bourreau too
      # (Note that the task will fail at Setup if the :share_wd_id attribute specify
      # a task that is now on the original Bourreau).
      # Duplicating a task could also be performed on the client side (BrainPortal).
      if (newstatus == 'Duplicate')
        new_bourreau_id = newparams['bourreau_id'] || @task.bourreau_id || RemoteResource.current_resource.id
        @new_task = @task.class.new(@task.attributes) # a kind of DUP!
        @new_task.bourreau_id   = new_bourreau_id
        @new_task.drmaa_jobid   = nil
        @new_task.drmaa_workdir = nil
        @new_task.run_number    = 1
        @new_task.status        = "New"
        @new_task.addlog_context(self,"Duplicated from task '#{@task.bname_tid}'.")
        @task=@new_task
      end

      if !@task.changed?
        format.xml { render :xml => @task.to_xml }
      elsif @task.save
        WorkerPool.find_pool(BourreauWorker).wake_up_workers
        format.xml { render :xml => @task.to_xml }
      else
        format.xml { render :xml => @task.errors.to_xml, :status => :unprocessable_entity }
      end
    end
  end
  
  # DELETE /tasks/<id>
  # Formats: xml
  def destroy #:nodoc:
    respond_to do |format|
      format.html { head :method_not_allowed }
      
      if @task.status =~ /Setting Up|Post Processing/ # TODO
        format.xml { head :ok }
      elsif @task.destroy
        WorkerPool.find_pool(BourreauWorker).wake_up_workers
        format.xml { head :ok }
      else
        format.xml { render :xml => @task.errors.to_xml, :status => :unprocessable_entity }
      end
    end
  end
  
  private

  def find_or_initialize_task
    if params[:id]
      if @task = DrmaaTask.find_by_id(params[:id], :conditions => { :bourreau_id => CBRAIN::BOURREAU_ID } )
        # No need to update the status anymore, the Workers do it.
        #@task.update_status
      else
        render_optional_error_file :not_found
      end
    else
      # This is all fuzzy logic trying to figure out the
      # expected real class for the new object, based on
      # the content of the keys and values of params
      subtypekey = params.keys.detect { |x| x =~ /^drmaa_/i }
      if subtypekey && subtypehash = params[subtypekey]
        subtype  = subtypehash[:type]
      end
      if !subtype && subtypekey # try another way
        subtype = subtypekey.camelize.sub(/^drmaa_/i,"Drmaa")
      end
      #token = subtypehash.delete(:originator_token)
      #cb_error "Un-authorized request" unless
      #  token && RemoteResource.valid_token?(token)
      @task = Class.const_get(subtype).new(subtypehash)
    end
  end

  def start_workers
    myself = RemoteResource.current_resource
    myself.send_command_start_workers
  end
  
  def check_sender
    token = request.headers["HTTP_CBRAIN_SENDER_TOKEN"]
    unless token && RemoteResource.valid_token?(token)
      head :bad_request
    end
  end

end
