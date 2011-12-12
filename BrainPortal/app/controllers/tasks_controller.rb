
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

  Revision_info=CbrainFileRevision[__FILE__]

  api_available

  before_filter :login_required

  def index #:nodoc:   
    @bourreaux = Bourreau.find_all_accessible_by_user(current_user)
    bourreau_ids = @bourreaux.map &:id
    
    # NOTE: 'scope' is no longer a scope, it's an ActiveRecord 3.0 'relation'
    if current_project
      @header_scope = CbrainTask.where( :group_id => current_project.id )
    else
      @header_scope = current_user.available_tasks
    end
    
    @header_scope = @header_scope.real_tasks
    scope = base_filtered_scope(@header_scope)
    
    @header_scope = @header_scope.where( :bourreau_id => bourreau_ids )
    
    if @filter_params["filter_hash"]["bourreau_id"].blank?
      scope = scope.where( :bourreau_id => bourreau_ids )
    end

    if request.format.to_sym == :xml
      @filter_params["sort_hash"]["order"] ||= "cbrain_tasks.updated_at"
      @filter_params["sort_hash"]["dir"]   ||= "DESC"
    else
      @filter_params["sort_hash"]["order"] ||= "cbrain_tasks.batch"
    end
    
    @sort_order = @filter_params["sort_hash"]["order"]
    @sort_dir   = @filter_params["sort_hash"]["dir"]
    # Set sort order and make it persistent.
    @showing_batch = false #i.e. don't show levels for individual entries.
    if @sort_order == "cbrain_tasks.batch"
      if @filter_params["filter_hash"]["launch_time"]
        @sort_order = "cbrain_tasks.updated_at"
        @sort_dir   = "DESC"
        @showing_batch   = true
      else
        @sort_order = 'cbrain_tasks.launch_time DESC, cbrain_tasks.created_at'
        @sort_dir   = 'DESC'
      end
    end

    # Handle custom filters
    @filter_params["filter_custom_filters_array"] ||= []
    @filter_params["filter_custom_filters_array"] &= current_user.custom_filter_ids.map(&:to_s)
    @filter_params["filter_custom_filters_array"].each do |custom_filter_id|
      custom_filter = TaskCustomFilter.find(custom_filter_id)
      scope = custom_filter.filter_scope(scope)
    end

    scope = scope.includes( [:bourreau, :user, :group] ).readonly

    @total_tasks       = scope.count    # number of TASKS
    @total_space_known = scope.sum(:cluster_workdir_size)
    @total_space_unkn  = scope.where(:cluster_workdir_size => nil).where("cluster_workdir IS NOT NULL").count
    @total_entries     = @total_tasks # number of ENTRIES, a batch line is 1 entry even if it represents N tasks

    # For Pagination
    offset = (@current_page - 1) * @per_page

    if @filter_params["sort_hash"]["order"] == "cbrain_tasks.batch" && !@filter_params["filter_hash"]["launch_time"] && request.format.to_sym != :xml
      @total_entries = scope.select( "distinct cbrain_tasks.launch_time" ).count
      launch_times   = scope.order( "#{@sort_order} #{@sort_dir}" ).offset( offset ).limit( @per_page ).group( :launch_time ).map(&:launch_time)

      @tasks = {} # hash lt => task_info
      launch_times.each do |lt|
         first_task     = scope.where(:launch_time => lt).order( [ :rank, :level, :id ] ).first
         tasks_in_batch = scope.where(:launch_time => lt).select( "user_id, group_id, bourreau_id, status, count(status) as status_count" ).group(:status).all
         statuses = {}
         tot_tasks = 0
         tasks_in_batch.each do |stat_info|
           the_stat = stat_info.status =~ /Fail/ ? "Failed" : stat_info.status
           the_cnt  = stat_info.status_count.to_i
           statuses[the_stat] ||= 0
           statuses[the_stat] += the_cnt
           tot_tasks          += the_cnt
         end
         @tasks[lt] = { :first_task => first_task, :statuses => statuses, :num_tasks => tot_tasks }
      end
      pagination_list = launch_times
    else
      
      if @showing_batch
        task_list = scope.all.sort { |t1,t2| t1.cmp_by_batch_rank(t2) }
        task_list = task_list[offset, @per_page]
      else
        task_list = scope.order( "#{@sort_order} #{@sort_dir}" ).offset( offset ).limit( @per_page )
      end
      
      @tasks = {}
      task_list.each do |t|
        @tasks[t.id] = { :first_task => t, :statuses => [t.status], :num_tasks => 1 }
      end
      pagination_list = task_list.map(&:id)
    end

    @paginated_list = WillPaginate::Collection.create(@current_page, @per_page) do |pager|
      pager.replace(pagination_list)
      pager.total_entries = @total_entries
      pager
    end

    @bourreau_status = {}
    status = @bourreaux.each { |bo| @bourreau_status[bo.id] = bo.online?}
    respond_to do |format|
      format.html
      format.xml  { render :xml => @tasks }
      format.js
    end
  end
  
  def batch_list #:nodoc:
    if current_project
      scope = CbrainTask.where( :group_id  => current_project.id )
    else
      scope = current_user.available_tasks
    end
    
    scope = base_filtered_scope(scope)
    
    scope = scope.where( :launch_time => params[:launch_time] )
    
    @bourreaux = Bourreau.find_all_accessible_by_user(current_user)
    if @filter_params["filter_hash"]["bourreau_id"].blank?
      scope = scope.where( :bourreau_id => @bourreaux.map(&:id) )
    end

    scope = scope.includes( [:bourreau, :user, :group] ).order( "cbrain_tasks.rank" ).readonly(false)
        
    @tasks = scope                     
    @bourreau_status = {}
    @bourreaux.each { |bo| @bourreau_status[bo.id] = bo.online?}    
    
    render :layout => false
  end
  
  # GET /tasks/1
  # GET /tasks/1.xml
  def show #:nodoc:
    task_id     = params[:id]

    @task              = current_user.available_tasks.find(task_id)
    @task.add_new_params_defaults # auto-adjust params with new defaults if needed
    @run_number        = params[:run_number] || @task.run_number

    if (request.format.to_sym != :xml) || params[:get_task_outputs]
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
    end

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @task }
    end
  end
  
  def new #:nodoc:
      
    if params[:tool_id].blank?
      flash[:error] = "Please select a task to perform."
      redirect_to :controller  => :userfiles, :action  => :index
      return
    end
    
    @toolname         = Tool.find(params[:tool_id]).cbrain_task_class.demodulize
    
    @task             = CbrainTask.const_get(@toolname).new

    # Our new task object needs some initializing
    @task.params      = @task.class.wrapper_default_launch_args.clone
    @task.bourreau_id = params[:bourreau_id] # may or may not be there
    @task.user        = current_user
    @task.group_id    = current_session[:active_group_id] || current_user.own_group.id
    @task.status      = "New"

    # Offer latest accessible tool config as default
    if @task.bourreau_id
      tool = @task.tool
      toolconfigs = ToolConfig.where( :bourreau_id => @task.bourreau_id, :tool_id => tool.id )
      toolconfigs.reject! { |tc| ! tc.can_be_accessed_by?(current_user) }
      lastest_toolconfig = toolconfigs.last
      @task.tool_config = lastest_toolconfig if lastest_toolconfig
    end

    # Filter list of files as provided by the get request
    file_ids = (params[:file_ids] || []) | current_session.persistent_userfile_ids_list
    @files            = Userfile.find_accessible_by_user(file_ids, current_user, :access_requested => :write) rescue []
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
        flash.now[:error] = message
      else
        flash.now[:notice] = message
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
    @task.add_new_params_defaults # auto-adjust params with new defaults if needed
    @toolname   = @task.name

    if @task.class.properties[:cannot_be_edited]
      flash[:error] = "This task is not meant to be edited.\n"
      redirect_to :action => :show, :id => params[:id]
      return
    end

    if @task.status !~ /Completed|Failed|Duplicated|Terminated/
      flash[:error] = "You cannot edit the parameters of an active task.\n"
      redirect_to :action => :show, :id => params[:id]
      return
    end

    # In order to edit older tasks that don't have :interface_userfile_ids
    # set, we initalize an empty one.
    params = @task.params
    params[:interface_userfile_ids] ||= []

    # Old API stored the data_provider_id in params, so move it
    @task.results_data_provider_id ||= params[:data_provider_id]
    params.delete(:data_provider_id) # keep it clean

    # Other common instance variables, such as @data_providers and @bourreaux
    initialize_common_form_values
    @bourreaux = [ @task.bourreau ] # override so we leave only one, even a non-active bourreau

    # Generate the form.
    respond_to do |format|
      format.html # edit.html.erb
    end

  end

  def create #:nodoc:
    flash[:notice]     = ""
    flash[:error]      = ""
    flash.now[:notice] = ""
    flash.now[:error]  = ""

    # For historical reasons, the web interface sends both a tool_id and a tool_config_id.
    # Only the tool_config_id is really necessary, as itself the tool_config object supplies
    # the tool_id and the bourreau_id.
    # For support with the external APIs, we'll try to guess missing values if we
    # only receive a tool_config_id.
    params_tool_config_id = params[:cbrain_task][:tool_config_id] # can be nil
    tool_config = ToolConfig.find(params_tool_config_id) rescue nil
    tool_config = nil unless tool_config && tool_config.can_be_accessed_by?(current_user) &&
                             tool_config.bourreau_and_tool_can_be_accessed_by?(current_user)
    if tool_config
      params[:tool_id]                   = tool_config.tool_id     # replace whatever was there or not
      params[:cbrain_task][:bourreau_id] = tool_config.bourreau_id # replace whatever was there or not
    else
      params[:cbrain_task][:tool_config_id] = nil # ZAP value, it's incorrect; will likely cause a validation error later on.
    end

    # A brand new task object!
    @toolname         = Tool.find(params[:tool_id]).cbrain_task_class.demodulize
    @task             = CbrainTask.const_get(@toolname).new(params[:cbrain_task])
    @task.user_id   ||= current_user.id
    @task.group_id  ||= current_session[:active_group_id] || current_user.own_group.id
    @task.status      = "New" if @task.status.blank? || @task.status !~ /Standby/ # Standby is special.

    # Extract the Bourreau ID from the ToolConfig
    tool_config = @task.tool_config
    @task.bourreau = tool_config.bourreau if tool_config && tool_config.bourreau

    # Security checks
    @task.user     = current_user           unless current_user.available_users.map(&:id).include?(@task.user_id)
    @task.group    = current_user.own_group unless current_user.available_groups.map(&:id).include?(@task.group_id)

    # Log revision number of portal.
    @task.addlog_current_resource_revision

    # Give a task the ability to do a refresh of its form
    commit_button = params[:commit] || "Start" # default
    if commit_button =~ /Refresh/i
      initialize_common_form_values
      flash.now[:notice] += @task.wrapper_refresh_form
      @task.valid? if @task.errors.empty?
      render :action => :new
      return
    end

    # Handle preset loads/saves
    unless @task.class.properties[:no_presets]
      if commit_button =~ /(load|delete|save) preset/i
        handle_preset_actions
        initialize_common_form_values
        render :action => :new
        return
      end
    end

    # TODO validate @task here and if anything is wrong, render :new again

    # Custom initializing
    messages = ""
    begin
      messages += @task.wrapper_after_form
    rescue CbrainError, CbrainNotice => ex
      @task.errors.add(:base, "#{ex.class.to_s.sub(/Cbrain/,"")} in form: #{ex.message}\n")
    end

    unless @task.errors.empty? && @task.valid?
      flash.now[:error] += messages
      initialize_common_form_values
      respond_to do |format|
        format.html { render :action => 'new' }
        format.xml  { render :xml => @task.errors }
      end    
      return
    end

    # Detect automatic parallelism support; in that case
    # the tasks are created in the 'Standby' state, then
    # passed to the CbrainTask::Parallelizer class to
    # launch (one or many) parallelizer objects too.
    parallel_size = nil
    prop_parallel = @task.class.properties[:use_parallelizer] # true, or a number
    tc_ncpus      = @task.tool_config.ncpus || 1
    if prop_parallel && (tc_ncpus > 1)
      if prop_parallel.is_a?(Fixnum) && prop_parallel > 1
        parallel_size = tc_ncpus < prop_parallel ? tc_ncpus : prop_parallel # min of the two
      else
        parallel_size = tc_ncpus
      end
      parallel_size = nil if parallel_size < 1 # no need then
    end

    # Disable parallelizer if no Tool object yet created.
    if parallel_size && ! CbrainTask::Parallelizer.tool
      parallel_size = nil
      messages += "\nWarning: parallelization cannot be performed until the admin configures a Tool for it.\n"
    end

    # Prepare final list of tasks; from the one @task object we have,
    # we get a full array of clones of that task in tasklist
    @task.launch_time = Time.now # so grouping will work
    tasklist,task_list_message = @task.wrapper_final_task_list
    unless task_list_message.blank?
      messages += "\n" unless messages.blank? || messages =~ /\n$/
      messages += task_list_message
    end
    
    # Spawn a background process to launch the tasks.
    CBRAIN.spawn_with_active_records_if(request.format.to_sym != :xml, :admin, "Spawn Tasks") do

      spawn_messages = ""

      tasklist.each do |task|
        begin
          if parallel_size && task.class == @task.class # Parallelize only tasks of same class as original
            if (task.status || 'New') !~ /New|Standby/ # making sure task programmer knows what he's doing
              raise ScriptError.new("Trying to parallelize a task, but the status was '#{task.status}' instead of 'New' or 'Standby'.")
            end
            task.status = "Standby" # force it there; the parallelizer with turn it back to 'New' later on
          else
            task.status = "New" if task.status.blank?
          end
          task.save!
        rescue => ex
          spawn_messages += "This task #{task.name} seems invalid: #{ex.class}: #{ex.message}.\n"
        end
      end

      spawn_messages += @task.wrapper_after_final_task_list_saved(tasklist)  # TODO check, use messages?

      # Create parallelizer, if needed
      if parallel_size
        paral_tasklist = tasklist.select { |t| t.class == @task.class }
        paral_info = CbrainTask::Parallelizer.create_from_task_list(paral_tasklist, :group_size => parallel_size)
        paral_messages = paral_info[0] # [1] is an array of Parallelizers, [2] an array of single tasks.
        if ! paral_messages.blank?
          spawn_messages += "\n" unless spawn_messages.blank? || spawn_messages =~ /\n$/
          spawn_messages += paral_messages
        end
      end

      # Send a start worker command to each affected bourreau
      bourreau_ids = tasklist.map &:bourreau_id
      bourreau_ids.uniq.each do |bourreau_id|
        Bourreau.find(bourreau_id).send_command_start_workers rescue true
      end

      unless spawn_messages.blank?
        Message.send_message(current_user, {
          :header        => "Submitted #{tasklist.size} #{@task.name} tasks; some messages follow.",
          :message_type  => :notice,
          :variable_text => spawn_messages
          }
        )
      end

    end

    if tasklist.size == 1
      flash[:notice] += "Launching a #{@task.name} task in background."
    else
      flash[:notice] += "Launching #{tasklist.size} #{@task.name} tasks in background."
    end
    flash[:notice] += "\n"            unless messages.blank? || messages =~ /\n$/
    flash[:notice] += messages + "\n" unless messages.blank?

    respond_to do |format|
      format.html { redirect_to :controller => :tasks, :action => :index }
      format.xml  { render :xml => tasklist }
    end
  end

  def update #:nodoc:

    flash[:notice]     = ""
    flash[:error]      = ""
    flash.now[:notice] = ""
    flash.now[:error]  = ""

    id = params[:id]
    @task = current_user.available_tasks.find(id)
    @task.add_new_params_defaults # auto-adjust params with new defaults if needed

    # Save old params and update the current task to reflect
    # the form's content.
    old_params   = @task.params.clone
    new_att      = params[:cbrain_task] || {} # not the TASK's params[], the REQUEST's params[]
    old_tool_config = @task.tool_config
    old_bourreau    = @task.bourreau
    @task.attributes = new_att # just updates without saving
    @task.restore_untouchable_attributes(old_params)

    # Bourreau ID must stay the same; tool config must be one associated with it
    @task.bourreau = old_bourreau
    unless @task.tool_config && @task.tool_config.bourreau_id == old_bourreau.id
      @task.tool_config = old_tool_config
    end

    # Security checks
    @task.user     = current_user           unless current_user.available_users.map(&:id).include?(@task.user_id)
    @task.group    = current_user.own_group unless current_user.available_groups.map(&:id).include?(@task.group_id)

    # Give a task the ability to do a refresh of its form
    commit_button = params[:commit] || "Start" # default
    if commit_button =~ /Refresh/i
      initialize_common_form_values
      flash[:notice] += @task.wrapper_refresh_form
      @task.valid? if @task.errors.empty?
      render :action => :edit
      return
    end

    # Handle preset loads/saves
    unless @task.class.properties[:no_presets]
      if commit_button =~ /(load|delete|save) preset/i
        handle_preset_actions
        initialize_common_form_values
        @bourreaux = [ @task.bourreau ] # override so we leave only one, even a non-active bourreau
        @task.valid?
        render :action => :edit
        return
      end
    end

    # Final update to the task object, this time we save it.
    messages = ""
    begin
      messages += @task.wrapper_after_form
    rescue CbrainError, CbrainNotice => ex
      @task.errors.add(:base, "#{ex.class.to_s.sub(/Cbrain/,"")} in form: #{ex.message}\n")
    end

    unless @task.errors.empty? && @task.valid?
      initialize_common_form_values
      flash.now[:error] += messages
      render :action => 'edit'
      return
    end

    # Log revision number of portal.
    @task.addlog_current_resource_revision

    @task.log_params_changes(old_params,@task.params)
    @task.save!

    flash[:notice] += messages + "\n" unless messages.blank?
    flash[:notice] += "New task parameters saved. See the log for changes, if any.\n"
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
    tasklist    = params[:tasklist]  || []
    tasklist    = [ tasklist ] unless tasklist.is_a?(Array)
    batch_ids   = params[:batch_ids] || []
    batch_ids   = [ batch_ids ] unless batch_ids.is_a?(Array)
    if batch_ids.delete "nil"
      tasklist += base_filtered_scope(CbrainTask.where( :launch_time => nil )).map(&:id)
    end
    tasklist += base_filtered_scope(CbrainTask.where( :launch_time => batch_ids )).map(&:id)

    tasklist = tasklist.map(&:to_i).uniq

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
          task = current_user.available_tasks.find(task_id)
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
            bourreau.send_command_alter_tasks(oktasks,new_status,params[:dup_bourreau_id]) # TODO parse returned command object?
            sent_ok += oktasks.size
          end
          sent_skipped += skippedtasks.size
        rescue => e # TODO record what error occured to inform user?
          sent_failed += btasklist.size
        end
      end # foreach bourreaux' tasklist

      if do_in_spawn
        Message.send_message(current_user, {
          :header        => "Finished sending '#{operation}' to your tasks.",
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

    #current_user.addlog_context(self,"Sent '#{operation}' to #{tasklist.size} tasks.")
    redirect_to :action => :index, :format  => request.format.to_sym

  end # method 'operation'



  #####################################################################
  # Private Methods For Form Support
  #####################################################################

  private

  # Some useful variables for the views for 'new' and 'edit'
  def initialize_common_form_values #:nodoc:

    @data_providers   = DataProvider.find_all_accessible_by_user(current_user).where( :online => true )

    # Find the list of Bourreaux that are both available and support the tool
    tool         = @task.tool
    bourreau_ids = tool.bourreaux.map &:id
    @bourreaux   = Bourreau.find_all_accessible_by_user(current_user).where( :online => true, :id => bourreau_ids )

    # Presets
    unless @task.class.properties[:no_presets]
      site_preset_tasks = []
      unless current_user.site.blank?
        manager_ids = current_user.site.managers.map &:id
        site_preset_tasks = CbrainTask.where( :status => 'SitePreset', :user_id => manager_ids )
      end
      own_preset_tasks = current_user.cbrain_tasks.where( :type => @task.class.to_s, :status => 'Preset' )
      @own_presets  = own_preset_tasks.collect  { |t| [ t.short_description, t.id ] }
      @site_presets = site_preset_tasks.collect { |t| [ "#{t.short_description} (by #{t.user.login})", t.id ] }
      @all_presets = []
      @all_presets << [ "Site Presets",     @site_presets ] if @site_presets.size > 0
      @all_presets << [ "Personal Presets", @own_presets  ] if @own_presets.size > 0
      @offer_site_preset = current_user.has_role? :site_manager
      #@own_presets = [ [ "Personal1", "1" ], [ "Personal2", "2" ] ]
      #@all_presets = [ [ "Site Presets", [ [ "Dummy1", "1" ], [ "Dummy2", "2" ] ] ], [ "Personal Presets", @own_presets ] ]
    end

    # Tool Configurations
    valid_bourreau_ids = @bourreaux.index_by &:id
    valid_bourreau_ids = { @task.bourreau_id => @task.bourreau } if ! @task.new_record? # existing tasks have more limited choices.
    @tool_configs      = tool.tool_configs # all of them, too much actually
    @tool_configs.reject! do |tc|
      tc.bourreau_id.blank? ||
      ! valid_bourreau_ids[tc.bourreau_id] ||
      ! tc.can_be_accessed_by?(@task.user)
    end

  end

  # This method handle the logic of loading and saving presets.
  def handle_preset_actions #:nodoc:
    commit_button = params[:commit] || "Whatever"

    if commit_button =~ /load preset/i
      preset_id = params[:load_preset_id] # used for delete too
      if (! preset_id.blank?) && preset = CbrainTask.where(:id => preset_id, :status => [ 'Preset', 'SitePreset' ]).first
        old_params = @task.params.clone
        @task.params         = preset.params
        @task.restore_untouchable_attributes(old_params, :include_unpresetable => true)
        if preset.group && preset.group.can_be_accessed_by?(current_user)
          @task.group = preset.group
        end
        if preset.tool_config && preset.tool_config.can_be_accessed_by?(current_user) && (@task.new_record? || preset.tool_config.bourreau_id == @task.bourreau_id)
          @task.tool_config = preset.tool_config
        end
        @task.bourreau = @task.tool_config.bourreau if @task.tool_config
        flash[:notice] += "Loaded preset '#{preset.short_description}'.\n"
      else
        flash[:notice] += "No preset selected, so parameters are unchanged.\n"
      end
    end

    if commit_button =~ /delete preset/i
      preset_id = params[:load_preset_id] # used for delete too
      if (! preset_id.blank?) && preset = CbrainTask.where(:id => preset_id, :status => [ 'Preset', 'SitePreset' ]).first
        if preset.user_id == current_user.id
          preset.delete
          flash[:notice] += "Deleted preset '#{preset.short_description}'.\n"
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
        preset    = CbrainTask.where(:id => preset_id, :status => [ 'Preset', 'SitePreset' ]).first
        cb_error "No such preset ID '#{preset_id}'" unless preset
        if preset.user_id != current_user.id
          flash[:error] += "Cannot update a preset that does not belong to you.\n"
          return
        end
        preset.params = @task.params.clone
      end

      # Cleanup stuff that don't need to go into a preset
      preset.status               = params[:save_as_site_preset].blank? ? 'Preset' : 'SitePreset'
      preset.bourreau             = nil # convention: presets have bourreau id set to 0
      preset.bourreau_id          = 0 # convention: presets have bourreau id set to 0
      preset.cluster_jobid        = nil
      preset.cluster_workdir      = nil
      preset.cluster_workdir_size = nil
      preset.launch_time          = nil
      preset.prerequisites        = {}
      preset.rank                 = 0
      preset.level                = 0
      preset.run_number           = nil
      preset.share_wd_tid         = nil
      preset.wrapper_untouchable_params_attributes.each_key do |untouch|
        preset.params.delete(untouch) # no need to save these eh?
      end
      preset.save!

      flash[:notice] += "Saved preset '#{preset.short_description}'.\n"
    end
  end

  def resource_class #:nodoc:
    CbrainTask
  end

  # Warning: private context in effect here.

end
