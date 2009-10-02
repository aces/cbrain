
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

      active_tasks = []
      begin # This block fetches from Bourreau ONLY the tasks in 'active' states.
        DrmaaTask.adjust_site(bourreau_id)
        raise "Failed to respond to 'alive' check" unless bourreau.is_alive?
        if current_user.has_role? :admin
          active_tasks = DrmaaTask.find(:all) || []
        else
          active_tasks = DrmaaTask.find(:all, :params => { :user_id => current_user.id } ) || []
        end
        active_tasks = [ active_tasks ] unless active_tasks.is_a?(Array)
      rescue => e
        bourreau_name = bourreau.name
        flash.now[:error] ||= ""
        flash.now[:error] += "Bourreau '#{bourreau_name}' is down: #{e.to_s}\n"

        # We recover by fetching directly from the DB...
        conditions = { :bourreau_id => bourreau_id,
                       :status      => DrmaaTask.active_status_keywords
                     }
        conditions.merge!( :user_id => current_user.id ) unless current_user.has_role? :admin
        active_tasks = ActRecTask.find(:all, :conditions => conditions)
        active_tasks.each do |t|  # ugly kludge
          t.updated_at = Time.parse(t.updated_at)
          t.created_at = Time.parse(t.created_at)
          t.status     = "UNKNOWN!" # ... but marking them as bad.
        end
      end
      @tasks.concat(active_tasks)

      # Now add the tasks in 'passive' states by accessing directly the DB
      conditions = { :bourreau_id => bourreau_id,
                     :status      => DrmaaTask.passive_status_keywords
                   }
      conditions.merge!( :user_id => current_user.id ) unless current_user.has_role? :admin
      passive_tasks = ActRecTask.find(:all, :conditions => conditions)
      passive_tasks.each do |t|  # ugly kludge
        t.updated_at = Time.parse(t.updated_at)
        t.created_at = Time.parse(t.created_at)
      end
      @tasks.concat(passive_tasks)
    end
    
    params[:sort_order] ||= 'updated_at'
    sort_order = params[:sort_order] 
    sort_dir   = params[:sort_dir]

    @tasks = @tasks.sort do |t1, t2|
      if sort_dir == 'DESC'
        task1 = t2
        task2 = t1
      else
        task1 = t1
        task2 = t2
      end
      
      case sort_order
      when 'type'
        task1.class.to_s <=> task2.class.to_s
      when 'owner'
        task1.user.login <=> task2.user.login
      when 'bourreau'
        task1.bourreau.name <=> task2.bourreau.name
      else
        task1.send(sort_order) <=> task2.send(sort_order)
      end
    end
        
    respond_to do |format|
      format.html
      format.js
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

    params[:user_id] = current_user.id

    # Simple case: the task has no parameter page, so submit
    # directly to 'create'
    if ! @task_class.has_args?
      redirect_to :action  => :create, :task  => params[:task], :file_ids  => params[:file_ids], :bourreau_id  => params[:bourreau_id]
      return
    end

    # The page has a parameter page, so get the default values....
    begin
      @default_args  = @task_class.get_default_args(params, current_user.user_preference.other_options[params[:task]])
    rescue  => e
      flash[:error] = e.to_s
      redirect_to userfiles_path
      return
    end
    
    # ... then generate the form.
    respond_to do |format|
      format.html # new.html.erb
    end

  end

  def create #:nodoc:
    @task_class = params[:task].constantize
    unless params[:bourreau_id].blank?
      @task_class.prefered_bourreau_id = params[:bourreau_id]
    else
      @task_class.prefered_bourreau_id = current_user.user_preference.bourreau_id
    end
    @task_class.data_provider_id     = params[:data_provider_id] || current_user.user_preference.data_provider
    
    if params[:save_as_defaults]
      current_user.user_preference.update_options(params[:task]  => @task_class.save_options(params))
      current_user.user_preference.save
    end
        
    begin
      params[:user_id] = current_user.id
      flash[:notice] ||= ""
      flash[:notice] += @task_class.launch(params)
      current_user.addlog_context(self,"Launched #{@task_class.to_s}")
      current_user.addlog_revinfo(@task_class)
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

    affected_tasks = []

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

      affected_tasks << task.bname_tid
    end

    message = "Sent '#{operation}' to tasks: #{affected_tasks.join(", ")}"

    current_user.addlog_context(self,message)
    flash[:notice] += message

    redirect_to :action => :index

  end

end
