
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
    @bourreaux = available_bourreaux(current_user)
    if current_user.has_role? :admin
      unless @filter_params["filters"]["owner_filter"].blank?
        conditions = { :user_id => @filter_params["filters"]["owner_filter"] }
      else
        conditions = {}
      end
    else
      conditions = { :user_id => current_user.id }
    end
    
    #Used to create filters
    @task_types = []
    @task_descriptions = []
    @task_owners = []
    @task_status = []
    ActRecTask.find(:all, :conditions =>conditions).each do |task|
      @task_types |= [task.class.to_s]
      @task_descriptions |= [task.description] if task.description
      @task_owners |= [task.user]
      @task_status |= [task.status]
    end
    
    if @filter_params["filters"]["bourreau_filter"]
      conditions[:bourreau_id] = @filter_params["filters"]["bourreau_filter"]
    else
      conditions[:bourreau_id] = @bourreaux.map { |b| b.id }
    end
    
    unless @filter_params["filters"]["status_filter"].blank?
      case @filter_params["filters"]["status_filter"].to_sym
      when :completed
        conditions[:status] = DrmaaTask::COMPLETED_STATUS
      when :running
        conditions[:status] = DrmaaTask::RUNNING_STATUS
      when :failed
        conditions[:status] = DrmaaTask::FAILED_STATUS
      else
        conditions[:status] = @filter_params["filters"]["status_filter"]
      end
    end

    unless @filter_params["filters"]["type_filter"].blank?
      conditions[:type] = @filter_params["filters"]["type_filter"]
    end
    
    unless @filter_params["filters"]["description_filter"].blank?
      conditions[:description] = @filter_params["filters"]["description_filter"]
    end

    @tasks = ActRecTask.find(:all, :conditions => conditions)
    
    @tasks.each do |t|  # ugly kludge
      t.updated_at = Time.parse(t.updated_at)
      t.created_at = Time.parse(t.created_at)
    end
    
    
    # Set sort order and make it persistent.
    @filter_params["sort"]["order"] ||= 'updated_at'
    @filter_params["sort"]["dir"]   ||= 'DESC'
    sort_order = @filter_params["sort"]["order"]
    sort_dir   = @filter_params["sort"]["dir"]  
    
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
        att1 = task1.class.to_s
        att2 = task2.class.to_s
      when 'owner'
        att1 = task1.user.login
        att2 = task2.user.login
      when 'bourreau'
        att1 = task1.bourreau.name
        att2 = task2.bourreau.name
      else
        att1 = task1.send(sort_order)
        att2 = task2.send(sort_order)
      end
      
      if att1.blank?
        1
      elsif att2.blank?
        -1
      else
        att1 <=> att2
      end
    end
        
    respond_to do |format|
      format.html
      format.js
    end
  end
  
  # GET /tasks/1
  # GET /tasks/1.xml
  def show #:nodoc:
    task_id     = params[:id]
    actrectask  = ActRecTask.find(task_id) # Fetch once...
    bourreau_id = actrectask.bourreau_id
    DrmaaTask.adjust_site(bourreau_id)     # ... to adjust this
    @task = DrmaaTask.find(task_id)        # Fetch twice... :-(

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @task }
    end
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
    rescue CbrainError => e
      flash[:error] = e.to_s
      redirect_to e.redirect || userfiles_path
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
    rescue CbrainError => e
      flash[:error] = e.to_s
      if e.redirect
        redirect_to e.redirect
      elsif @task_class.has_args?
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
  #[*Hold*] Put the task on hold (while it is queued).
  #[*Release*] Release task from <tt>On Hold</tt> status (i.e. put it back in the queue).
  #[*Suspend*] Stop processing of the task (while it is on cpu).
  #[*Resume*] Release task from <tt>Suspended</tt> status (i.e. continue processing).
  #[*Terminate*] Kill the task, while maintaining its temporary files and its entry in the database.
  #[*Delete*] Kill the task, delete the temporary files and remove its entry in the database. 
  def operation
    operation   = params[:operation]
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

    # Prepare counters for how many tasks affected.
    sent_ok      = 0
    sent_failed  = 0
    sent_skipped = 0

    # Decide in which conditions we spawn a background job to send
    # the operation to the tasks...
    do_in_spawn  = tasklist.size > 5

    # This block will either run in background or not depending
    # on do_in_spawn
    CBRAIN.spawn_with_active_records_if(do_in_spawn,current_user,"Sending #{operation} to a list of tasks") do

    tasklist.each do |task_id|

      begin 
        actrectask  = ActRecTask.find(task_id) # Fetch once...
        bourreau_id = actrectask.bourreau_id
        DrmaaTask.adjust_site(bourreau_id)     # ... to adjust this
        task = DrmaaTask.find(task_id.to_i)    # Fetch twice... :-(
      rescue
        sent_failed += 1
        next
      end

      if task.user_id != current_user.id && current_user.role != 'admin'
        sent_skipped += 1
        continue 
      end

      begin
        if operation == 'delete'
          task.destroy
          sent_ok += 1
        else
          cur_status  = task.status
          allowed_new = DrmaaTask::AllowedOperations[cur_status] || []
          new_status  = DrmaaTask::OperationToNewStatus[operation]
          if new_status && allowed_new.include?(new_status)
            task.status = new_status
            if task.save
              sent_ok += 1
            else
              sent_failed += 1
            end
          else
            sent_skipped += 1
          end
        end
      rescue => e # TODO record what error occured to inform user?
        sent_failed += 1
      end

    end # foreach task ID

    if do_in_spawn
      Message.send_message(current_user, {
        :header        => "Finished sending #{operation} to #{tasklist.size} tasks.",
        :message_type  => :notice,
        :variable_text => "Number of tasks notified: #{sent_ok} OK, #{sent_skipped} skipped, #{sent_failed} failed.\n"
        }
      )
    end

    end # End of spawn_if block

    if do_in_spawn
      flash[:notice] = "The tasks are being notified in background."
    else
      flash[:notice] = "Number of tasks notified: #{sent_ok} OK, #{sent_skipped} skipped, #{sent_failed} failed.\n"
    end

    current_user.addlog_context(self,"Sent '#{operation}' to #{tasklist.size} tasks.")
    redirect_to :action => :index

  end # method 'operation'

end
