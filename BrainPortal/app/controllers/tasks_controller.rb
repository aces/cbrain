
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

    if current_project
      scope = CbrainTask.scoped(:conditions  => {:group_id  => current_project.id}, :include => [ :user, :group ] )
    else
      scope = current_user.available_tasks
    end
    
    unless @filter_params["filters"]["user_id"].blank?
      scope = scope.scoped(:conditions => {:user_id => @filter_params["filters"]["user_id"]})
    end
    
    #Used to create filters
    @task_types = []
    @task_owners = []
    @task_projects = []
    @task_status = []
    scope.find(:all).each do |task|
      @task_types |= [task.class.to_s]
      @task_owners |= [task.user]
      @task_projects |= [task.group]
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

    scope = scope.scoped(:include  => [:bourreau, :user, :group], 
                         :readonly => false, 
                         :order    => "#{@filter_params["sort"]["order"]} #{@filter_params["sort"]["dir"]}" )

    @tasks = scope
    
    page = (params[:page] || 1).to_i
    @tasks_per_page = 20
    @filter_params["pagination"] ||= "on"
    @per_page = @filter_params["pagination"] == "on" ? @tasks_per_page : 999_999_999
    
    if @filter_params["sort"]["order"] == 'cbrain_tasks.launch_time DESC, cbrain_tasks.created_at'
      @tasks = @tasks.group_by(&:launch_time)
    end
    
    @total_tasks = @tasks.size
    @tasks = WillPaginate::Collection.create(page, @per_page) do |pager|
      pager.replace(@tasks.slice((page-1) * @per_page, @per_page))
      pager.total_entries = @total_tasks
      pager
    end
    
    @bourreau_status = {}
    status = @bourreaux.each { |bo| @bourreau_status[bo.id] = bo.online?}

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
    @run_number        = params[:run_number] || @task.run_number

    begin
      bourreau           = @task.bourreau
      control            = bourreau.send_command_get_task_outputs(task_id,@run_number)
      @task.cluster_stdout = control.cluster_stdout
      @task.cluster_stderr = control.cluster_stderr
      @task.script_text    = control.script_text
    rescue Errno::ECONNREFUSED, EOFError, ActiveResource::ServerError, ActiveResource::TimeoutError, ActiveResource::MethodNotAllowed
      flash.now[:notice] = "Warning: the Execution Server '#{bourreau.name}' for this task is not available right now."
      @task.cluster_stdout = "Execution Server is DOWN!"
      @task.cluster_stderr = "Execution Server is DOWN!"
      @task.script_text    = nil
    end

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @task }
    end
  end
  
  def new #:nodoc:
    
    unless params[:toolname] 
      if params[:scientific_operation].blank?
        task = params[:conversion_operation]
      else
        task = params[:scientific_operation]
      end
      task.sub!(/^CbrainTask::/,"")
      params[:toolname]  = task
    end
    
    if request.format.to_sym == :js
      render :text  => "window.location='#{url_for(:controller  => :tasks, :action  => :new, :toolname  => params[:toolname], :bourreau_id  => params[:bourreau_id], :file_ids  => params[:file_ids] )}'"
      return
    end
    
    # Brand new task object for the form
    @toolname         = params[:toolname]
    if @toolname.blank?
      flash[:error] = "Please select a task to perform."
      redirect_to :controller  => :userfiles, :action  => :index
      return
    end
    
    @task             = CbrainTask.const_get(@toolname).new

    # Our new task object needs some initializing
    @task.params      = @task.class.wrapper_default_launch_args.clone
    @task.bourreau_id = params[:bourreau_id]
    @task.user_id     = current_user.id
    @task.group_id    = current_session[:active_group_id] || current_user.own_group.id
    if @task.bourreau_id
      tool = @task.tool
      lastest_toolconfig = ToolConfig.find(:last, :conditions => { :bourreau_id => @task.bourreau_id, :tool_id => tool.id })
      @task.tool_config_id = lastest_toolconfig.id if lastest_toolconfig
    end

    # Filter list of files as provided by the get request
    @files            = Userfile.find_accessible_by_user(params[:file_ids], current_user, :access_requested => :write) rescue []
    if @files.empty?
      flash[:error] = "You must select at least one file to which you have write access."
      redirect_to :controller  => :userfiles, :action  => :index
      return
    end
    
    @task.params[:interface_userfile_ids] = @files.map &:id

    # Other common instance variables, such as @data_providers and @bourreaux
    initialize_common_form_values

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

  # Catch any exception and re-raise them with a proper redirect.
  rescue => ex
    if ex.is_a?(CbrainException) && ex.redirect.nil?
      ex.redirect = { :controller => :userfiles, :action => :index }
    end
    raise ex
  end

  def edit #:nodoc:
    @task       = current_user.available_tasks.find(params[:id])
    @toolname   = @task.name

    if @task.status !~ /Completed|Failed/
      flash[:error] = "You cannot edit the parameters of an active task.\n";
      redirect_to :action => :show, :id => params[:id]
      return
    end

    # In order to edit older tasks that don't have :interface_userfile_ids
    # set, we initalize an empty one.
    params = @task.params
    params[:interface_userfile_ids] ||= []

    # Other common instance variables, such as @data_providers and @bourreaux
    initialize_common_form_values
    @bourreaux = [ @task.bourreau ] # override so we leave only one, even a non-active bourreau

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

    flash[:notice] = ""
    flash[:error]  = ""

    # A brand new task object!
    @toolname         = params[:toolname]
    @task             = CbrainTask.const_get(@toolname).new(params[:cbrain_task])
    @task.user_id   ||= current_user.id
    @task.group_id  ||= current_session[:active_group_id] || current_user.own_group.id

    # Decode the selection box with combined bourreau_id and tool_config_id
    bid_tcid = params[:bid_tcid] || "," # comma important
    bid,tcid = bid_tcid.split(",")
    @task.bourreau_id    = bid.to_i  if bid
    @task.tool_config_id = tcid.to_i if tcid

    # Security checks
    @task.user_id     = current_user.id           unless current_user.available_users.map(&:id).include?(@task.user_id)
    @task.group_id    = current_user.own_group_id unless current_user.available_groups.map(&:id).include?(@task.group_id)

    # Log revision number of portal.
    @task.addlog_current_resource_revision

    # Handle preset loads/saves
    unless @task.class.properties[:no_presets]
      commit_button = params[:commit] || "Start" # default
      if commit_button =~ /(load|delete|save) preset/i
        handle_preset_actions
        initialize_common_form_values
        flash[:notice] += @task.wrapper_before_form
        render :action => :new
        return
      end
    end

    # Choose a Bourreau if none selected
    if @task.bourreau_id.blank?
      initialize_common_form_values  # We call this just for getting @bourreaux
      if @task.tool_config && @task.tool_config.bourreau
        @bourreaux = [ @task.tool_config.bourreau ] # use the one in tool_config
      end
      if @bourreaux.size == 0
        flash[:error] += "No Execution Server available right now for this task?"
        redirect_to :action  => :new, :file_ids => @task.params[:interface_userfile_ids], :toolname => @toolname
        return
      else
        @task.bourreau_id = @bourreaux[rand(@bourreaux.size)].id
      end
    end

    # TODO validate @task here and if anything is wrong, render :new again

    # Custom initializing
    messages = ""
    messages += @task.wrapper_after_form

    @task.launch_time = Time.now # so grouping will work
    tasklist = @task.wrapper_final_task_list
    
    tasklist.each do |task|
      task.status = "New" if task.status.blank?
      begin
        task.save!
      rescue => ex
        messages += "This task #{task.name} seems invalid: #{ex.class}: #{ex.message}.\n"
      end
    end

    messages += @task.wrapper_after_final_task_list_saved(tasklist)  # TODO check

    flash[:notice] += messages if messages
    if tasklist.size == 1
      flash[:notice] += "Launched a #{@task.name} task."
    else
      flash[:notice] += "Launched #{tasklist.size} #{@task.name} tasks."
    end

    # Send a start worker command to each affected bourreau
    CBRAIN.spawn_with_active_records(:nobody,"Trigger workers") do
      bourreau_ids = tasklist.map &:bourreau_id
      bourreau_ids.uniq.each do |bourreau_id|
        Bourreau.find(bourreau_id).send_command_start_workers # rescue true
      end
    end

    redirect_to :controller => :tasks, :action => :index
  end

  def update #:nodoc:

    flash[:notice] = ""
    flash[:error]  = ""

    id = params[:id]
    @task = current_user.available_tasks.find(id)

    # Save old params and update the current task to reflect
    # the form's content.
    old_params   = @task.params.clone
    new_att      = params[:cbrain_task] || {}
    @task.attributes = new_att # just updates without saving
    restore_untouchable_attributes(@task,old_params)

    # Security checks
    @task.user_id     = current_user.id           unless current_user.available_users.map(&:id).include?(@task.user_id)
    @task.group_id    = current_user.own_group_id unless current_user.available_groups.map(&:id).include?(@task.group_id)

    # Decode the selection box with combined bourreau_id and tool_config_id
    bid_tcid = params[:bid_tcid] || "," # comma important
    bid,tcid = bid_tcid.split(",")
    #@task.bourreau_id    = bid.to_i  if bid # we no not change the bourreau_id
    @task.tool_config_id = tcid.to_i if tcid

    # Handle preset loads/saves
    unless @task.class.properties[:no_presets]
      commit_button = params[:commit] || "Update" # default
      if commit_button =~ /(load|delete|save) preset/i
        handle_preset_actions
        initialize_common_form_values
        @bourreaux = [ @task.bourreau ] # override so we leave only one, even a non-active bourreau
        flash[:notice] += @task.wrapper_before_form
        render :action => :edit
        return
      end
    end

    # Final update to the task object, this time we save it.
    messages     = @task.wrapper_after_form

    # Log revision number of portal.
    @task.addlog_current_resource_revision

    @task.log_params_changes(old_params,@task.params)
    @task.save!

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
        bid       = pair_bid_tasklist[0]
        btasklist = pair_bid_tasklist[1]
        bourreau  = Bourreau.find(bid)
        begin
          if operation == 'delete'
            bourreau.send_command_alter_tasks(btasklist,'Destroy') # TODO parse returned command object?
            sent_ok += btasklist.size
            next
          end
          new_status  = PortalTask::OperationToNewStatus[operation] # from HTML form keyword to Task object keyword
          oktasks = btasklist.select do |t|
            cur_status  = t.status
            allowed_new = PortalTask::AllowedOperations[cur_status] || []
            new_status && allowed_new.include?(new_status)
          end
          skippedtasks = btasklist - oktasks
          if oktasks.size > 0
            bourreau.send_command_alter_tasks(oktasks,new_status) # TODO parse returned command object?
            sent_ok += oktasks.size
          end
          sent_skipped += skippedtasks.size
        rescue => e # TODO record what error occured to inform user?
          sent_failed += btasklist.size
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
    redirect_to :action => :index, :format  => request.format.to_sym

  end # method 'operation'



  #####################################################################
  # Private Methods For Form Support
  #####################################################################

  private

  # Some useful variables for the views for 'new' and 'edit'
  def initialize_common_form_values #:nodoc:

    @data_providers   = DataProvider.find_all_accessible_by_user(current_user, :conditions => { :online => true } )

    # Find the list of Bourreaux that are both available and support the tool
    tool       = @task.tool
    @bourreaux = tool.bourreaux.find_all_accessible_by_user(current_user, :conditions => { :online => true } )

    # Presets
    unless @task.class.properties[:no_presets]
      site_preset_tasks = []
      unless current_user.site.blank?
        manager_ids = current_user.site.managers.map &:id
        site_preset_tasks = CbrainTask.find(:all, :conditions => { :status => 'SitePreset', :user_id => manager_ids })
      end
      own_preset_tasks = current_user.cbrain_tasks.find(:all, :conditions => { :type => @task.class.to_s, :status => 'Preset' })
      @own_presets  = own_preset_tasks.collect  { |t| [ t.description, t.id ] }
      @site_presets = site_preset_tasks.collect { |t| [ "#{t.description} (by #{t.user.login})", t.id ] }
      @all_presets = []
      @all_presets << [ "Site Presets",     @site_presets ] if @site_presets.size > 0
      @all_presets << [ "Personal Presets", @own_presets  ] if @own_presets.size > 0
      @offer_site_preset = current_user.has_role? :site_manager
      #@own_presets = [ [ "Personal1", "1" ], [ "Personal2", "2" ] ]
      #@all_presets = [ [ "Site Presets", [ [ "Dummy1", "1" ], [ "Dummy2", "2" ] ] ], [ "Personal Presets", @own_presets ] ]
    end

    # Tool Configurations
    valid_bourreau_ids = @bourreaux.index_by &:id
    valid_bourreau_ids = { @task.bourreau_id => @task.bourreau } if @task.id # existing tasks have more limited choices.
    all_tool_configs   = tool.tool_configs # all of them, too much actually
    all_tool_configs.reject! { |tc| tc.bourreau_id.blank? || ! valid_bourreau_ids[tc.bourreau_id] }

    @tool_configs_select = []   # [ [ groupname, [ [pair], [pair] ] ], [ groupname, [ [pair], [pair] ] ] ]
    ordered_bourreaux = valid_bourreau_ids.values.sort { |a,b| a.name <=> b.name }
    ordered_bourreaux.each do |bourreau|
      bourreau_name   = bourreau.name
      my_tool_configs = all_tool_configs.select { |tc| tc.bourreau_id == bourreau.id }
      pairlist        = []
      if my_tool_configs.size == 0
        pairlist << [ "Default", "#{bourreau.id}," ] # the comma is important in the string!
      else
        my_tool_configs.each do |tc|
          desc = tc.short_description
          pairlist << [ desc, "#{bourreau.id},#{tc.id.to_s}" ]
        end
      end
      @tool_configs_select << [ "On #{bourreau_name}:", pairlist ]
    end

  end

  # This method handle the logic of loading and saving presets.
  def handle_preset_actions #:nodoc:
    commit_button = params[:commit] || "Whatever"

    if commit_button =~ /load preset/i
      preset_id = params[:load_preset_id] # used for delete too
      if (! preset_id.blank?) && preset = CbrainTask.find(:first, :conditions => { :id => preset_id, :status => [ 'Preset', 'SitePreset' ] })
        old_params = @task.params.clone
        @task.params         = preset.params
        restore_untouchable_attributes(@task,old_params)
        @task.group_id       = preset.group_id       if preset.group_id
        @task.bourreau_id    = preset.bourreau_id    if preset.bourreau_id
        @task.tool_config_id = preset.tool_config_id if preset.tool_config_id
        flash[:notice] += "Loaded preset '#{preset.description}'.\n"
      else
        flash[:notice] += "No preset selected, so parameters are unchanged.\n"
      end
    end

    if commit_button =~ /delete preset/i
      preset_id = params[:load_preset_id] # used for delete too
      if (! preset_id.blank?) && preset = CbrainTask.find(:first, :conditions => { :id => preset_id, :status => [ 'Preset', 'SitePreset' ] })
        if preset.user_id == current_user.id
          preset.delete
          flash[:notice] += "Deleted preset '#{preset.description}'.\n"
        else
          flash[:notice] += "Cannot delete a preset that doesn't belong to you.\n"
        end
      else
        flash[:notice] += "No preset selected, so parameters are unchanged.\n"
      end
    end

    if commit_button =~ /save preset/i
      preset_name = params[:save_preset_name]
      preset = nil
      if ! preset_name.blank?
        preset = @task.clone
        preset.description = preset_name
      else
        preset_id = params[:save_preset_id]
        preset    = CbrainTask.find(:first, :conditions => { :id => preset_id, :status => [ 'Preset', 'SitePreset' ] })
        cb_error "No such preset ID '#{preset_id}'" unless preset
        if preset.user_id != current_user.id
          flash[:error] += "Cannot update a preset that does not belong to you.\n"
          return
        end
        preset.params = @task.params.clone
      end
      preset.bourreau_id = 0
      preset.status = params[:save_as_site_preset].blank? ? 'Preset' : 'SitePreset'
      preset.wrapper_untouchable_params_attributes.each_key do |untouch|
        preset.params.delete(untouch) # no need to save these eh?
      end
      preset.save!
      flash[:notice] += "Saved preset '#{preset.description}'.\n"
    end
  end

  # TODO: maybe this should be in the task model
  def restore_untouchable_attributes(task,old_params) #:nodoc:
    cur_params = task.params
    untouchables = task.wrapper_untouchable_params_attributes
    untouchables.each_key do |untouch|
      cur_params[untouch] = old_params[untouch] if old_params.has_key?(untouch)
    end
  end

  # Warning: private context in effect here.

end
