
#
# CBRAIN Project
#
# Task controller for the BrainPortal interface
#
# Original author: Pierre Rioux
#
# $Id$
#

#Restful controller for the CbrainTask resource.
class TasksController < ApplicationController

  Revision_info="$Id$"

  before_filter :login_required

  def index #:nodoc:   
    @bourreaux = Bourreau.find_all_accessible_by_user(current_user)
    scope = CbrainTask.scoped({})
    if current_user.has_role? :admin
      unless @filter_params["filters"]["user_id"].blank?
        scope = scope.scoped(:conditions => {:user_id => @filter_params["filters"]["user_id"]})
      end
    else
      scope = scope.scoped(:conditions => {:user_id => current_user.id} )
    end
    
    #Used to create filters
    @task_types = []
    @task_descriptions = []
    @task_owners = []
    @task_status = []
    scope.find(:all).each do |task|
      @task_types |= [task.class.to_s]
      @task_descriptions |= [task.description] if task.description
      @task_owners |= [task.user]
      @task_status |= [task.status]
    end
    
    @filter_params["filters"].each do |att, val|
      att = att.to_sym
      next if att == :user_id
      value = val
      case att
      when :status
        case value.to_sym
        when :completed
          value = CbrainTask::COMPLETED_STATUS
        when :running
          value = CbrainTask::RUNNING_STATUS
        when :failed
          value = CbrainTask::FAILED_STATUS
        end 
      end
      if att == :custom_filter
        custom_filter = TaskCustomFilter.find(value)
        scope = custom_filter.filter_scope(scope)
      else
        scope = scope.scoped(:conditions => {att => value})
      end
    end

    if @filter_params["filters"]["bourreau_id"].blank?
      scope = scope.scoped( :conditions  => {:bourreau_id  => @bourreaux.map { |b| b.id }} )
    end

    # Set sort order and make it persistent.
    @filter_params["sort"]["order"] ||= 'cbrain_tasks.launch_time DESC, cbrain_tasks.created_at'
    @filter_params["sort"]["dir"]   ||= 'DESC'

    scope = scope.scoped(:joins  => [:bourreau, :user], 
                         :readonly  => false, 
                         :order => "#{@filter_params["sort"]["order"]} #{@filter_params["sort"]["dir"]}" )

    @tasks = scope
    
    if @filter_params["sort"]["order"] == 'cbrain_tasks.launch_time DESC, cbrain_tasks.created_at'
      @tasks = @tasks.group_by(&:launch_time)
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

    @task              = CbrainTask.find(task_id)

    begin
      bourreau           = @task.bourreau
      control            = bourreau.send_command_get_task_outputs(task_id)
      @task.cluster_stdout = control.cluster_stdout
      @task.cluster_stderr = control.cluster_stderr
    rescue Errno::ECONNREFUSED, EOFError
      flash[:notice] = "Warning: the Execution Server for this task is not available right now"
      @task.cluster_stdout = "Execution Server is DOWN!"
      @task.cluster_stderr = "Execution Server is DOWN!"
    end

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @task }
    end
  end
  
  def new #:nodoc:

    # Brand new task object for the form
    @toolname         = params[:toolname]
    @task             = CbrainTask.const_get(@toolname).new

    # Some useful variables for the view
    @data_providers   = available_data_providers(current_user)

    # Tarek modify this please. Also see the same code in new(), edit() and create()
    @bourreaux        = Bourreau.find_all_accessible_by_user(current_user).select{ |b| b.online == true }
    @tool_bourreaux   = Tool.find_by_cbrain_task_class(@task.class.to_s).bourreaux
    @bourreaux        = @bourreaux & @tool_bourreaux

    # Our new task object needs some initializing
    @task.params      = @task.class.wrapper_default_launch_args.dup
    @task.bourreau_id = params[:bourreau_id]
    @task.user_id     = current_user.id

    # Filter list of files as provided by the get request
    @files            = Userfile.find_accessible_by_user(params[:file_ids], current_user, :access_requested => :write)
    @task.params[:interface_userfile_ids] = @files.map &:id

    # Custom initializing
    message = @task.wrapper_before_form
    unless message.blank?
      if message =~ /error/i
        flash[:error] = message
      else
        flash[:notice] = message
      end
    end

    # Generate the form.
    respond_to do |format|
      format.html # new.html.erb
    end

  end

  def edit #:nodoc:
    @task       = current_user.cbrain_tasks.find(params[:id])
    @toolname   = @task.name

    if @task.status !~ /Completed|Failed/
      flash[:error] = "You cannot edit the parameters of an active task.\n";
      redirect_to :action => :show, :id => params[:id]
      return
    end

    # Some useful variables for the view
    @data_providers   = available_data_providers(current_user)

    # In order to edit older tasks that don't have :interface_userfile_ids
    # set, we initalize an empty one.
    params = @task.params
    params[:interface_userfile_ids] ||= []

    # Custom initializing
    message = @task.wrapper_before_form
    unless message.blank?
      if message =~ /error/i
        flash[:error] = message
      else
        flash[:notice] = message
      end
    end

    # Generate the form.
    respond_to do |format|
      format.html # edit.html.erb
    end

  end

  def create #:nodoc:

    flash[:notice] ||= ""
    flash[:error]  ||= ""

    @toolname         = params[:toolname]
    @task             = CbrainTask.const_get(@toolname).new(params[:cbrain_task])
    @task.user_id     = current_user.id

    unless @task.bourreau_id
      # Tarek modify this please. Also see the same code in new() and create()
      @bourreaux        = Bourreau.find_all_accessible_by_user(current_user).select{ |b| b.online == true }
      @tool_bourreaux   = Tool.find_by_cbrain_task_class(@task.class.to_s).bourreaux
      @bourreaux        = @bourreaux & @tool_bourreaux
      if @bourreaux.size == 0
        flash[:error] = "No Execution Server available right now for this task?"
        redirect_to :action  => :new, :file_ids => @task.file_ids, :toolname => @toolname
        return
      else
        @task.bourreau_id = @bourreaux[0].id
      end
    end

    # TODO @task validation here !

    # Custom initializing
    messages = ""
    messages += @task.wrapper_after_form

    tasklist = @task.wrapper_final_task_list

    @task.launch_time = Time.now # so grouping will work
    
    tasklist.each do |task|
      if task.new_record? && task.status.blank?
        task.status = "New"
        task.save!  # TODO check
      else
        messages += "Task seems invalid: #{task.inspect}"
      end
    end

    messages += @task.wrapper_after_final_task_list_saved(tasklist)  # TODO check

    flash[:notice] += messages if messages
    if tasklist.size == 1
      flash[:notice] += "Launched a #{@task.name} task."
    else
      flash[:notice] += "Launched #{tasklist.size} #{@task.name} tasks."
    end

    redirect_to :controller => :tasks, :action => :index
  end

  def update #:nodoc:
    id = params[:id]
    @task = CbrainTask.find(id)  # the original one
    old_params = @task.params
    new_att    = params[:cbrain_task] || {}
    @task.update_attributes(new_att)
    messages = @task.wrapper_after_form
    new_params = @task.params
    @task.log_params_changes(old_params,new_params)
    @task.save
    flash[:notice] = messages if messages
    redirect_to :action => :show, :id => @task.id
  end

  #This action handles requests to modify the status of a given task.
  #Potential operations are:
  #[*Hold*] Put the task on hold (while it is queued).
  #[*Release*] Release task from <tt>On Hold</tt> status (i.e. put it back in the queue).
  #[*Suspend*] Stop processing of the task (while it is on cpu).
  #[*Resume*] Release task from <tt>Suspended</tt> status (i.e. continue processing).
  #[*Terminate*] Kill the task, while maintaining its temporary files and its entry in the database.
  #[*Delete*] Kill the task, delete the temporary files and remove its entry in the database. 
  def operation #:nodoc:
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

      tasks = []
      tasklist.each do |task_id|

        begin
          task = CbrainTask.find(task_id)
        rescue
          sent_failed += 1
          next
        end

        if task.user_id != current_user.id && current_user.role != 'admin'
          sent_skipped += 1
          next 
        end

        tasks << task
      end

      grouped_tasks = tasks.group_by &:bourreau_id

      grouped_tasks.each do |pair_bid_tasklist|
        bid      = pair_bid_tasklist[0]
        tasklist = pair_bid_tasklist[1]
        bourreau = Bourreau.find(bid)
        begin
          if operation == 'delete'
            bourreau.send_command_alter_tasks(tasklist,'Destroy') # TODO parse returned command object?
            sent_ok += tasklist.size
            next
          end
          new_status  = CbrainTask::PortalTask::OperationToNewStatus[operation] # from HTML form keyword to Task object keyword
          oktasks = tasklist.select do |t|
            cur_status  = t.status
            allowed_new = CbrainTask::PortalTask::AllowedOperations[cur_status] || []
            new_status && allowed_new.include?(new_status)
          end
          skippedtasks = tasklist - oktasks
          if oktasks.size > 0
            bourreau.send_command_alter_tasks(oktasks,new_status) # TODO parse returned command object?
            sent_ok += oktasks.size
          end
          sent_skipped += skippedtasks.size
        rescue => e # TODO record what error occured to inform user?
          sent_failed += tasklist.size
        end
      end # foreach bourreaux' tasklist

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
      flash[:notice] += "The tasks are being notified in background."
    else
      flash[:notice] += "Number of tasks notified: #{sent_ok} OK, #{sent_skipped} skipped, #{sent_failed} failed.\n"
    end

    current_user.addlog_context(self,"Sent '#{operation}' to #{tasklist.size} tasks.")
    redirect_to :action => :index

  end # method 'operation'

end
