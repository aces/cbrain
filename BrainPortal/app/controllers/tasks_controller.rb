
#
# CBRAIN Project
#
# Task controller for the BrainPortal interface
#
# Original author: Pierre Rioux
#
# $Id$
#

#Restful controller for the DrmaaTask resource.
class TasksController < ApplicationController

  Revision_info="$Id$"

  before_filter :login_required
   
  def index #:nodoc:
    @tasks = []
    @bourreaux = available_bourreaux(current_user)
    @bourreaux.each do |bourreau|
      bourreau_id = bourreau.id
      DrmaaTask.adjust_site(bourreau_id)
      begin
        if current_user.has_role? :admin
          #tasks = DrmaaTask.find(:all) || []
          tasks = DrmaaTask.find(:all, :include => [:user, :bourreau]) || []
        else
          tasks = DrmaaTask.find(:all, :include => [:user, :bourreau], :params => { :user_id => current_user.id } ) || []
        end
        tasks = [ tasks ] unless tasks.is_a?(Array)
        @tasks.concat(tasks)
      rescue => e
        bourreau_name = bourreau.name
        flash.now[:error] ||= ""
        flash.now[:error] += "Bourreau '#{bourreau_name}' is down: #{e.to_s}\n"
      end
    end
  end

  # GET /tasks/3/1
  # GET /tasks/3/1.xml
  def show #:nodoc:
    bourreau_id = params[:bourreau_id]
    DrmaaTask.adjust_site(bourreau_id)
    @task = DrmaaTask.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @task }
    end

  rescue
    access_error(404)
  end
  
  def new #:nodoc:
    @task_class = Class.const_get(params[:task].to_s)
    @files = Userfile.find_accessible_by_user(params[:file_ids], current_user, :access_requested  => :read)
    @data_providers = available_data_providers(current_user)
        
    if @task_class.has_args?
      begin
        @default_args  = @task_class.get_default_args(params, current_user.user_preference.other_options[params[:task]])
      rescue  => e
        flash[:error] = e.to_s
        redirect_to userfiles_path
        return
      end
    else
      redirect_to :action  => :create, :task  => params[:task], :file_ids  => params[:file_ids]
      return
    end
    
    respond_to do |format|
      format.html # new.html.erb
    end

  end

  def create #:nodoc:
    @task_class = params[:task].constantize
    @task_class.prefered_bourreau_id = current_user.user_preference.bourreau_id
    @task_class.data_provider_id     = params[:data_provider_id] || current_user.user_preference.data_provider
    
    if params[:save_as_defaults]
      current_user.user_preference.update_options(params[:task]  => @task_class.save_options(params))
      current_user.user_preference.save
    end
        
    begin
      flash[:notice] ||= ""
      flash[:notice] += @task_class.launch(params)
    rescue  => e
      flash[:error] = e.to_s
      if @task_class.has_args?
        redirect_to :action  => :new, :file_ids => params[:file_ids], :task  => params[:task]
      else
        redirect_to userfiles_path
      end
      return
    end
    
    redirect_to :controller => :tasks, :action => :index
  end

  #This action handles requests to modify the status of a given task.
  #Potential operations are:
  #[*Postprocess*] If processing of the task is completed, sync files from
  #                the task's working directory back to the system.
  #[*Hold*] Put the task on hold (while it is queued).
  #[*Release*] Release task from <tt>On Hold</tt> status (i.e. put it back in the queue).
  #[*Suspend*] Stop processing of the task (while it is on cpu).
  #[*Resume*] Release task from <tt>Suspended</tt> status (i.e. continue processing).
  #[*Terminate*] Kill the task, while maintaining its temporary files and its entry in the database.
  #[*Delete*] Kill the task, delete the temporary files and remove its entry in the database. 
  def operation
    if params[:commit] == 'Trigger postprocessing of selected tasks'
      operation = 'postprocess'
    else
      operation   = params[:operation]
    end
    
    tasklist    = params[:tasklist] || []

    flash[:error]  ||= ""
    flash[:notice] ||= ""

    if operation.nil? || operation.empty?
       flash[:notice] += "Task list has been refreshed.\n"
       redirect_to :action => :index
       return
     end

    if tasklist.empty?
      flash[:error] += "No task selected? Selection cleared.\n"
      redirect_to :action => :index
      return
    end

    tasklist.each do |task_bid_tid|

      (bourreau_id,task_id) = task_bid_tid.split(/,/)
      begin 
        DrmaaTask.adjust_site(bourreau_id)
        task = DrmaaTask.find(task_id.to_i)
      rescue
        flash[:error] += "Task #{task_id} does not exist."
        next
      end

      continue if task.user_id != current_user.id && current_user.role != 'admin'

      case operation
        when "postprocess"
          task.status = "postprocess"  # keyword is significant
          task.save
        when "hold"
          task.status = "On Hold"
          task.save
        when "release"
          task.status = "Queued"
          task.save
        when "suspend"
          task.status = "Suspended"
          task.save
        when "resume"
          task.status = "On CPU"
          task.save
        when "delete"
          task.destroy
        when "terminate"
          task.status = "Terminated"
          task.save
      end

      flash[:notice] += "Sent '#{operation}' operation to task #{task.id}.\n"
    end

    redirect_to :action => :index

  end

  
end
