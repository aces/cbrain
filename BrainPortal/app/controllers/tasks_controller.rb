
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# RESTful controller for the CbrainTask resource.
class TasksController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  api_available :except => [:update, :destroy, :zenodo, :create_zenodo, :reset_zenodo ]

  before_action :login_required

  def index #:nodoc:
    @scope      = scope_from_session

    # Default sorting order and batch mode
    if api_request?
      scope_default_order(@scope, 'updated_at', :desc)
    else
      scope_default_order(@scope, 'rank')
      @scope.custom[:batch] = true if @scope.custom[:batch].nil?
    end

    @scope.pagination ||= Scope::Pagination.from_hash({ :per_page => 25 })
    @base_scope   = user_scope(current_user.available_tasks)
      #.includes([:bourreau, :user, :group])
    @custom_scope = custom_scope(@base_scope)
    @view_scope   = @scope.apply(@custom_scope)

    # Display totals
    @total_tasks       = @view_scope.count
    @total_space_known = @view_scope.sum(:cluster_workdir_size)
    @total_space_unkn  = @view_scope
      .where(:cluster_workdir_size => nil)
      .where('cluster_workdir IS NOT NULL')
      .count

    # Batch mode & pagination
    single_batch    = @scope.filters.any? { |f| f.attribute == 'batch_id' }
    @showing_batch  = @scope.custom[:batch] && single_batch

    if ! api_request? && @scope.custom[:batch] && ! single_batch
      @tasks = @scope.pagination.apply(@view_scope.group(:batch_id).count.to_a)
      @tasks.map! do |id, count|
        first = @view_scope
            .where(:batch_id => id)
            .order(['cbrain_tasks.rank', 'cbrain_tasks.level', 'cbrain_tasks.id'])
            .first

        { :batch => id, :first => first, :count => count } if first
      end
      @tasks.compact!
    else
      @tasks = @scope.pagination.apply(@view_scope).to_a
      if ! api_request?
        @tasks.map! do |task|
          { :batch => task.batch_id, :first => task, :count => 1 }
        end
      end
    end

    # Bourreaux status
    @bourreau_status = Bourreau.find_all_accessible_by_user(current_user)
      .map { |b| [b.id, b.online?] }
      .to_h

    # Save the modified scope object
    scope_to_session(@scope)

    respond_to do |format|
      format.html
      format.js
      format.xml  { render :xml  => @tasks.sort_by(&:id).for_api_xml }
      format.json { render :json => @tasks.sort_by(&:id).for_api     }
    end
  end

  # Renders a set of tasks associated with a batch.
  def batch_list
    @scope = scope_from_session('tasks#index')
    @scope.order.clear

    @base_scope = custom_scope(user_scope(
      current_user
        .available_tasks
        .real_tasks
        .where(:batch_id => params[:batch_id])
        #.includes([:bourreau, :user, :group])
    ))

    @tasks = @scope.apply(@base_scope)
      .order(['cbrain_tasks.rank', 'cbrain_tasks.level', 'cbrain_tasks.id'])
      .map { |task| { :batch => task.batch_id, :first => task, :count => 1 } }

    @bourreau_status = Bourreau
      .find_all_accessible_by_user(current_user)
      .map { |b| [b.id, b.online?] }
      .to_h

    @row_fetch = true

    render :partial => 'tasks_display', :layout => false
  end


  # GET /tasks/1
  # GET /tasks/1.xml
  def show #:nodoc:
    task_id     = params[:id]
    @scope      = scope_from_session('tasks#index')

    @task              = current_user.available_tasks.find(task_id)
    @task_batch_count  = current_user.available_tasks.where(:batch_id => @task.batch_id).count

    @task.add_new_params_defaults # auto-adjust params with new defaults if needed
    @run_number        = params[:run_number] || @task.run_number

    @stdout_lim        = params[:stdout_lim].to_i
    @stdout_lim        = 2000 if @stdout_lim <= 100 || @stdout_lim > 999999

    @stderr_lim        = params[:stderr_lim].to_i
    @stderr_lim        = 2000 if @stderr_lim <= 100 || @stderr_lim > 999999

    if ((! api_request?) || params[:get_task_outputs]) && @task.full_cluster_workdir.present? && ! @task.workdir_archived?
      begin
        @task.capture_job_out_err(@run_number,@stdout_lim,@stderr_lim) # PortalTask method: sends command to bourreau to get info
      rescue Errno::EADDRNOTAVAIL, # all sorts of things can go wrong here
             Errno::ECONNREFUSED,
             Errno::ECONNRESET,
             EOFError,
             ActiveResource::ServerError,
             ActiveResource::TimeoutError,
             ActiveResource::MethodNotAllowed,
             ActiveResource::ResourceNotFound
        flash.now[:notice] = "Warning: the Execution Server '#{@task.bourreau.name}' for this task is not available right now."
        @task.cluster_stdout = "Execution Server is DOWN!"
        @task.cluster_stderr = "Execution Server is DOWN!"
        @task.script_text    = nil
      end
    end

    # This variable can be used by the task's _show_params partial
    # to selectively display pieces of information based on the
    # current version of the tool, using things like @tool_config.is_at_least_version('2.0.0).
    @tool_config = @task.tool_config

    respond_to do |format|
      format.html # show.html.erb
      format.xml   { render :xml  => @task.for_api_xml }
      format.json  { render :json => @task.for_api     }
    end
  end

  def new #:nodoc:

    # NOTE: Sep 2021 The entire logic while entering this action is
    # to be redesigned. We should require a tool_config_id as a preference,
    # and a tool_id + bourreau_id as a second option (and then maybe not at all)

    # This ID normally implies both what tool and what bourreau to use
    tool_config_id = params[:tool_config_id].presence
    # These two are fallback for compatibility reasons
    tool_id        = params[:tool_id].presence
    bourreau_id    = params[:bourreau_id].presence

    # SANITY CHECKS ON TOOL_CONFIG_ID, TOOL_ID and BOURREAU_ID
    autoconfig = false
    if tool_config_id # the prefered method
      @tool_config = ToolConfig.find(tool_config_id)
      if ! @tool_config.can_be_accessed_by?(current_user)
         raise ActiveRecord::RecordNotFound.new("Cannot access ToolConfig ##{tool_config_id}")
      end
    else # Try to propose a version; usually that's when we get just a tool_id
      if tool_id.blank?
        flash[:error] = "Please select a tool to run."
        redirect_to :controller  => :userfiles, :action  => :index
        return
      end
      tool = Tool.find(tool_id)
      if ! tool.can_be_accessed_by?(current_user)
         raise ActiveRecord::RecordNotFound.new("Cannot access Tool ##{tool_id}")
      end
      bourreau_id = Bourreau.find_all_accessible_by_user(current_user).where(:online => true).pluck(:id) if bourreau_id.nil? # try them all
      toolconfigs = ToolConfig.where(
         :bourreau_id => bourreau_id,
         :tool_id     => tool.id,
      ).order(:created_at).to_a
      toolconfigs.reject! { |tc| ! tc.can_be_accessed_by?(current_user) }
      if toolconfigs.empty?
        flash[:error] = "We can't find any versions of the tool #{tool.name} available right now."
        redirect_to :controller  => :userfiles, :action  => :index
        return
      end
      @tool_config = toolconfigs.last
      autoconfig = true
    end

    # Now that we sanitized the tool config...
    tool           = @tool_config.tool
    tool_id        = @tool_config.tool_id
    tool_config_id = @tool_config.id
    bourreau_id    = @tool_config.bourreau_id

    # Create the new task object
    @task       = tool.cbrain_task_class.new
    @toolname   = tool.name

    # Our new task object needs some initializing
    @task.bourreau_id    = bourreau_id
    @task.tool_config_id = tool_config_id
    @task.user           = current_user
    @task.group_id       = current_assignable_group.id
    @task.status         = "New"
    @task.params         = @task.wrapper_default_launch_args.clone

    # Filter list of files as provided by the get request
    file_ids = params[:file_ids] || []
    cb_file_ids    = CbrainFileList.where(:id => file_ids).pluck(:id)
    other_file_ids = file_ids.map(&:to_i) - cb_file_ids
    if @tool_config.try(:inputs_readonly) || @task.class.properties[:readonly_input_files]
      access = :read
    else
      access = :write
    end
    cb_files     = Userfile.find_accessible_by_user(cb_file_ids, current_user, :access_requested => :read) rescue []
    other_files  = Userfile.find_accessible_by_user(other_file_ids, current_user, :access_requested => access) rescue []
    @files = cb_files + other_files
    if @files.count != file_ids.count
      flash[:error] = "Select files to which you have #{access} access."
      flash[:error] = "You must select at least one file." if @files.count == 0
      redirect_to :controller  => :userfiles, :action  => :index
      return
    end

    # Check that input files are accessible from selected Bourreau
    if @task.bourreau_id
      dp_ids_of_inputs = @files.map(&:data_provider_id).uniq
      bad_dps = DataProvider.where(:id => dp_ids_of_inputs).to_a.select do |dp|
        ! dp.rr_allowed_syncing?(@task.bourreau)
      end
      if bad_dps.present?
        flash[:error] =
          "Some selected files are stored on Data Providers that are\n" +
          "not accessible from execution server #{@task.bourreau.name}:\n\n" +
          (bad_dps.map do |dp|
            num_files =  @files.count { |f| f.data_provider_id == dp.id }
            "Data Provider '#{dp.name}' : #{view_pluralize(num_files, "file")}\n"
          end).join
        redirect_to :controller  => :userfiles, :action  => :index
        return
      end
    end

    @task.params[:interface_userfile_ids] = @files.map(&:id)

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

    # Warn about archived files
    archived_files = @files.select { |f| f.is_a?(FileCollection) && f.archived? }
    if archived_files.present?
        flash.now[:notice] ||= ""
        flash.now[:notice]  += "\nWarning: some of the files you selected are currently archived. This is probably not how you want to process them. Consider unarchiving them before launching this task. Archived files: #{archived_files.map(&:name).join(", ")}"
    end

    # Print message of the tool config was 'guessed'
    if autoconfig
      flash.now[:notice] ||= ""
      flash.now[:notice]  += "\nWe have automatically chosen the latest version and execution server for this tool (version #{@tool_config.version_name} on #{@task.bourreau.name}), please double-check this configuration."
      #@task.errors.add(:tool_config_id, "was chosen for you, make sure this is what you want.")
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
    @task        = current_user.available_tasks.find(params[:id])
    @task.add_new_params_defaults # auto-adjust params with new defaults if needed
    @toolname    = @task.name
    @tool_config = @task.tool_config

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
    # set, we initialize an empty one.
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

    new_task_params = task_params() # filters and censors

    @task           = create_initial_task_from_form(new_task_params, params[:tool_id])
    @tool_config    = @task.tool_config # for acces in view

    # Give a task the ability to do a refresh of its form
    commit_name     = extract_params_key([ :refresh, :load_preset, :delete_preset, :save_preset ])
    commit_name     = :refresh if params[:commit] =~ @task.refresh_form_regex
    if commit_name == :refresh
      initialize_common_form_values
      flash.now[:notice] += @task.wrapper_refresh_form
      @task.valid? if @task.errors.empty?
      render :action => :new
      return
    end

    # Handle preset loads/saves
    unless @task.class.properties[:no_presets]
      if commit_name == :load_preset || commit_name == :delete_preset || commit_name == :save_preset
        handle_preset_actions
        initialize_common_form_values
        render :action => :new
        return
      end
    end

    # Callback: custom initialization before launching
    messages = ""
    messages += @task.wrapper_after_form

    # New behavior: user *must* provide a destination data provider;
    # we can't really force it in the model with a require_presence_of
    # because of the large history of old tasks that don't have
    # the attribute set.
    if @task.results_data_provider_id.blank? || @task.results_data_provider.blank?
      @task.errors[:results_data_provider_id] = 'must be provided'
    end

    if @tool_config && @tool_config.bourreau.present? && ! @tool_config.bourreau.online?
      @task.errors[:tool_config_id] = 'is on an Execution Server that is currently offline'
    end

    unless @task.errors.empty? && @task.valid?
      flash.now[:error] += messages
      initialize_common_form_values
      respond_to do |format|
        format.html { render :action => 'new' }
        format.xml  { render :xml  => @task.errors, :status => :unprocessable_entity }
        format.json { render :json => @task.errors, :status => :unprocessable_entity }
      end
      return
    end

    # Create a bunch of tasks and launch them, either in background or in foreground
    tasklist,messages = create_tasklist_from_initial_task(@task)

    if tasklist.size == 1
      flash[:notice] += "Launching a #{@task.pretty_name} task in background."
    else
      flash[:notice] += "Launching #{tasklist.size} #{@task.pretty_name} tasks in background."
    end
    flash[:notice] += "\n"            unless messages.blank? || messages =~ /\n$/
    flash[:notice] += messages + "\n" unless messages.blank?

    # Increment the number of times the user has launched this particular tool
    tool_id                           = @task.tool.id
    top_tool_ids                      = current_user.meta[:top_tool_ids] || {}
    top_tool_ids[tool_id]             = (top_tool_ids[tool_id].presence || 0) + 1
    current_user.meta[:top_tool_ids]  = top_tool_ids rescue nil # the rescue is in case of race conditions :-(

    respond_to do |format|
      format.html { redirect_to :controller => :tasks, :action => :index }
      format.xml  { render :xml  => tasklist.sort_by(&:id).for_api_xml }
      format.json { render :json => tasklist.sort_by(&:id).for_api     }
    end
  end

  def update #:nodoc:

    flash[:notice]     = ""
    flash[:error]      = ""
    flash.now[:notice] = ""
    flash.now[:error]  = ""

    id         = params[:id]
    @task      = current_user.available_tasks.find(id)
    old_params = @task.params.clone
    @task.add_new_params_defaults # auto-adjust params with new defaults if needed

    # Save old attributes and update the current task to reflect
    # the form's content.
    new_task_attr          = task_params # not the TASK's params[], the REQUEST's params[]
    new_task_attr.delete(:batch_id) # cannot be changed.

    old_tool_config  = @task.tool_config
    old_bourreau     = @task.bourreau
    @task.attributes = new_task_attr # just updates without saving
    @task.restore_untouchable_attributes(old_params)

    # Bourreau ID must stay the same; tool config must be one associated with it
    @task.bourreau = old_bourreau
    unless @task.tool_config && @task.tool_config.bourreau_id == old_bourreau.id
      @task.tool_config = old_tool_config
    end

    # Security checks
    @task.user_id  = @task.changed_attributes['user_id']  || @task.user_id   unless current_user.available_users.map(&:id).include?(@task.user_id)
    @task.group_id = @task.changed_attributes['group_id'] || @task.group_id  unless current_user.assignable_groups.map(&:id).include?(@task.group_id)

    # Give a task the ability to do a refresh of its form
    commit_name = extract_params_key([ :refresh, :load_preset, :delete_preset, :save_preset ], :whatever)
    commit_name = :refresh if params[:commit] =~ @task.refresh_form_regex
    if commit_name == :refresh
      initialize_common_form_values
      flash[:notice] += @task.wrapper_refresh_form
      @task.valid? if @task.errors.empty?
      render :action => :edit
      return
    end

    # Handle preset loads/saves
    unless @task.class.properties[:no_presets]
      if commit_name == :load_preset || commit_name == :delete_preset || commit_name == :save_preset
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

    # Log task params changes
    @task.log_params_changes(old_params,@task.params)

    # Log and save normal attributes of the task
    @task.save_with_logging(current_user, %w( results_data_provider_id ))

    flash[:notice] += messages + "\n" unless messages.blank?
    flash[:notice] += "New task parameters saved. See the logs for changes, if any.\n"
    redirect_to :action => :show, :id => @task.id
  end

  # Allows user to update attributes of multiple tasks.
  def update_multiple
    @scope = scope_from_session('tasks#index')

    # Construct task_ids and batch_ids
    task_ids   = Array(params[:tasklist]  || [])
    batch_ids  = Array(params[:batch_ids] || [])
    batch_ids << nil if batch_ids.delete('nil')
    task_ids  += filtered_scope(CbrainTask.where(:batch_id => batch_ids)).select('cbrain_tasks.id').raw_first_column
    task_ids   = task_ids.map(&:to_i).uniq

    commit_name = extract_params_key([ :update_user_id, :update_group_id, :update_results_data_provider_id, :update_tool_config_id ])

    # If commit_name undef
    unless commit_name.present?
      flash[:error] = "No operation to perform."
      redirect_to :action => :index, :format  => request.format.to_sym
      return
    end

    unable_to_update = ""
    new_task_attr    = task_params
    field_to_update  =
      case commit_name
        when :update_user_id
          new_user_id = new_task_attr[:user_id].to_i
          unable_to_update = "user"   if
          ! current_user.available_users.where(:id => new_user_id).exists?
          :user
        when :update_group_id
          new_group_id = new_task_attr[:group_id].to_i
          unable_to_update = "project" if
          ! current_user.assignable_groups.where(:id => new_group_id).exists?
          :group
        when :update_results_data_provider_id
          new_dp_id = new_task_attr[:results_data_provider_id].to_i
          unable_to_update = "data provider" if
          ! DataProvider.find_all_accessible_by_user(current_user).where(:id => new_dp_id).exists?
          :results_data_provider
        when :update_tool_config_id
          new_tool_config = ToolConfig.find(new_task_attr[:tool_config_id].to_i)
          unable_to_update = "tool version" if
            ! new_tool_config.bourreau_and_tool_can_be_accessed_by?(current_user)
          :tool_config
        else
        :unknown
      end

    if unable_to_update.present?
      flash[:error] = "You do not have access to this #{unable_to_update}."
      redirect_to :action => :index, :format  => request.format.to_sym
      return
    end

    # For unknown field
    if field_to_update == :unknown
      flash[:error] = "Unknown field to update."
      redirect_to :action => :index, :format  => request.format.to_sym
      return
    end

    do_in_spawn   = task_ids.size > 5
    success_list  = []
    failed_list   = {}

    CBRAIN.spawn_with_active_records_if(do_in_spawn,current_user,"Sending update to tasks") do
      accessible_bourreau = Bourreau.find_all_accessible_by_user(current_user)
      tasklist            = CbrainTask.where(:id => task_ids, :bourreau_id => accessible_bourreau).all.to_a

      # Remove tasks who aren't accessible by current_user
      new_tasklist = tasklist.dup
      new_tasklist.reject! { |task| ! task.has_owner_access?(current_user) }
      failed_tasks = tasklist - new_tasklist
      failed_list["you don't have access to this task(s)"]  = failed_tasks if failed_tasks.present?
      tasklist     = new_tasklist

      operation =
        case field_to_update
          when :user
            ["update_attributes", {:user_id => new_user_id}]
          when :group
            user_to_avail_group_ids = {}
            new_tasklist = tasklist.dup
            new_tasklist.reject! do |task|
              t_uid = task.user_id
              # Task user need to have access to new group
              user_to_avail_group_ids[t_uid] ||= User.find(t_uid).assignable_group_ids.index_by { |id| id }
              (! user_to_avail_group_ids[t_uid][new_group_id])
            end
            failed_tasks = tasklist - new_tasklist
            failed_list["new group is not accessible by task's owner"] = failed_tasks if failed_tasks.present?
            tasklist     = new_tasklist
            ["update_attributes", {:group_id => new_group_id}]
          when :results_data_provider
            user_to_avail_dp_ids = {}
            new_tasklist = tasklist.dup
            new_tasklist.reject! do |task|
              t_uid = task.user_id
              # Task user need to have access to new data provider
              user_to_avail_dp_ids[t_uid] ||= DataProvider.find_all_accessible_by_user(User.find(t_uid)).index_by { |dp| dp.id }
              (! user_to_avail_dp_ids[t_uid][new_dp_id])
            end
            failed_tasks = tasklist - new_tasklist
            failed_list["new data provider is not accessible by task's owner"] = failed_tasks if failed_tasks.present?
            tasklist     = new_tasklist
            ["update_attributes", {:results_data_provider_id => new_dp_id}]
          when :tool_config
            user_to_avail_new_tool_config = {}
            old_tcid_to_tool_id           = {}
            new_tasklist = tasklist.dup
            new_tasklist.reject! do |task|
              t_uid    = task.user_id
              old_tcid = task.tool_config_id
              old_bid  = task.bourreau_id
              # Task user need to have access to bourreau and tool linked to tool_config
              user_to_avail_new_tool_config[t_uid] ||= new_tool_config.bourreau_and_tool_can_be_accessed_by?(User.find(t_uid)) ? 1 : 0
              # old tool_config and new tool_config need to concern same tool
              old_tcid_to_tool_id[old_tcid] ||= ToolConfig.find(old_tcid).tool_id
              # (user has access to new tc)                     (new tc is same tool as old tc)                         (new tc has same bourreau as old tc)
              (user_to_avail_new_tool_config[t_uid] == 0) || (old_tcid_to_tool_id[old_tcid] != new_tool_config.tool_id) || (old_bid != new_tool_config.bourreau_id)
            end
            failed_tasks = tasklist - new_tasklist
            failed_list["error when updating tool config"] = failed_tasks if failed_tasks.present?
            tasklist     = new_tasklist
            ["update_attributes", {:tool_config_id => new_tool_config.id}]
        end

      tasklist.each { |task| success_list << task if task.send(*operation) }

      if do_in_spawn
        # Message for successful actions
        if success_list.present?
          notice_message_sender("Finished sending update to your task(s)", success_list)
        end
        # Message for failed actions
        if failed_list.present?
          error_message_sender("Failed to update your task(s)", failed_list)
        end
      end

    end # End of spawn_if block

    if do_in_spawn
      flash[:notice] = "The tasks are being updated in background."
    else
     flash[:notice] = "Successfully updated #{view_pluralize(success_list.count, "task")}." if success_list.present?
     failure_count  = 0
     failed_list.each_value { |v| failure_count += v.size }
     flash[:error]  = "Failed to update #{view_pluralize(failure_count, "task")}." if failure_count > 0
    end

    redirect_to :action => :index, :format  => request.format.to_sym
  end

  # This action handles requests to modify the status of a given task.
  # Potential operations are:
  # [*Hold*] Put the task on hold (while it is queued).
  # [*Release*] Release task from <tt>On Hold</tt> status (i.e. put it back in the queue).
  # [*Suspend*] Stop processing of the task (while it is on cpu).
  # [*Resume*] Release task from <tt>Suspended</tt> status (i.e. continue processing).
  # [*Terminate*] Kill the task, while maintaining its temporary files and its entry in the database.
  # [*Delete*] Kill the task, delete the temporary files and remove its entry in the database.
  def operation
    @scope = scope_from_session('tasks#index')

    operation  = params[:operation]
    tasklist   = params[:tasklist]  || []
    tasklist   = [ tasklist ]  unless tasklist.is_a?(Array)
    batch_ids  = params[:batch_ids] || []
    batch_ids  = [ batch_ids ] unless batch_ids.is_a?(Array)
    batch_ids << nil if batch_ids.delete('nil')
    tasklist  += filtered_scope(CbrainTask.where(:batch_id => batch_ids)).raw_first_column("cbrain_tasks.id")
    tasklist   = tasklist.map(&:to_i).uniq
    tasklist   = current_user.available_tasks.where(:id => tasklist).pluck(:id)

    flash[:error]  ||= ""
    flash[:notice] ||= ""

    if operation.nil? || operation.empty?
      flash[:notice] += "Task list has been refreshed.\n"
      redirect_to :action => :index
      return
    end

    if tasklist.empty?
      flash[:error] += "No task selected?.\n"
      redirect_to :action => :index
      return
    end

    # Some security validations
    dup_bourreau_id = params[:dup_bourreau_id].presence # for 'duplicate' operation
    archive_dp_id   = params[:archive_dp_id].presence   # for 'archive as file' operation
    dup_bourreau_id = nil unless dup_bourreau_id && Bourreau.find_all_accessible_by_user(current_user).where(:id => dup_bourreau_id).exists?
    archive_dp_id   = nil unless archive_dp_id   && DataProvider.find_all_accessible_by_user(current_user).where(:id => archive_dp_id).exists?

    # This does the actual work and returns info about the
    # successes and failures.
    results = apply_operation(operation, tasklist,
      :dup_bourreau_id => dup_bourreau_id,
      :archive_dp_id   => archive_dp_id,
    )

    # Prepare counters for how many tasks affected.
    skipped_list = results[:skipped_list]
    success_list = results[:success_list]
    failed_list  = results[:failed_list]

    failure_size  = 0
    failed_list.each_value  { |v| failure_size += v.size }
    skipped_size  = 0
    skipped_list.each_value { |v| skipped_size += v.size }
    flash[:notice] += "Number of tasks notified: #{success_list.size} OK, #{skipped_size} skipped, #{failure_size} failed.\n"

    respond_to do |format|
      format.html { redirect_to :action => :index }
      format.js   { redirect_to :action => :index }
      format.json { head :ok }
      format.xml  { head :ok }
    end
  end # method 'operation'

  # This applies an 'operation' to a set of tasks, like 'delete', or
  # 'archive' or 'terminate'. Since the operations are performed by
  # the bourreaux, not the portals, a message is sent to those bourreaux.
  #
  # +options+ contains some more parameters for tasks being archived
  # or duplicated.
  #
  # Returns a simple hash with some list for successes, failures and
  # skipped operations
  def apply_operation(operation, taskids, options = {})

    # Some other parameters
    dup_bourreau_id = options[:dup_bourreau_id] # for 'duplicate' operation
    archive_dp_id   = options[:archive_dp_id]   # for 'archive as file' operation

    # Prepare counters for how many tasks affected.
    skipped_list = {}
    success_list = []
    failed_list  = {}

    # Background Activity lookup table
    operation_to_bac = {
      "terminate"    => BackgroundActivity::TerminateTask,
      "archive"      => BackgroundActivity::ArchiveTaskWorkdir,
      "archive_file" => BackgroundActivity::ArchiveTaskWorkdir,
      "unarchive"    => BackgroundActivity::UnarchiveTaskWorkdir,
      "zap_wd"       => BackgroundActivity::RemoveTaskWorkdir,
      "save_wd"      => BackgroundActivity::SaveTaskWorkdir,
      "hold"         => BackgroundActivity::HoldTask,
      "release"      => BackgroundActivity::ReleaseTask,
      "suspend"      => BackgroundActivity::SuspendTask,
      "resume"       => BackgroundActivity::ResumeTask,
      "duplicate"    => BackgroundActivity::DuplicateTask,
      "recover"      => BackgroundActivity::RecoverTask,
      "restart_setup"       => BackgroundActivity::RestartTask,
      "restart_cluster"     => BackgroundActivity::RestartTask,
      "restart_postprocess" => BackgroundActivity::RestartTask,
    }

    # The weird new indentation starting here is because a 'spawn' wrapping block was removed.

      tasks = CbrainTask.where(:id => taskids).to_a

      # Go through tasks, grouped by bourreau
      grouped_tasks = tasks.group_by(&:bourreau_id)
      grouped_tasks.each do |pair_bid_tasklist|
        bid       = pair_bid_tasklist[0]
        btasklist = pair_bid_tasklist[1]
        bourreau  = Bourreau.find(bid)
        begin

          # MASS DELETE
          if operation == 'delete'
            # Two sublists, to optimize the delete
            can_be_just_deleted = btasklist.select { |t| t.cluster_workdir.blank? }
            must_remote_delete  = btasklist - can_be_just_deleted
            can_be_just_deleted.each do |t|
              begin
                t.destroy
                success_list << t
              rescue => e
                failed_list[e.message] ||= []
                failed_list[e.message] << t
              end
            end
            bac=BackgroundActivity::DestroyTask.local_new(current_user.id, must_remote_delete.map(&:id),bid)
            # The .save below will just be ignored if the items list is empty
            bac.save
            success_list += must_remote_delete
            next
          end

          # MASS NEW STATUS
          new_status  = PortalTask::OperationToNewStatus[operation] # from HTML form keyword to Task object keyword
          oktasks = btasklist.select do |t|
            cur_status  = t.status
            allowed_new = PortalTask::AllowedOperations[cur_status] || []
            new_status && allowed_new.include?(new_status)
          end
          if oktasks.size > 0
            bac_klass = operation_to_bac[operation]
            if bac_klass
              bac = bac_klass.local_new(current_user.id, oktasks.map(&:id), bid, {})
              bac.options[:archive_data_provider_id] = archive_dp_id   if operation == 'archive_file'
              bac.options[:dup_bourreau_id]          = dup_bourreau_id if operation == 'duplicate'
              bac.options[:atwhat]                   = 'Setup'         if operation == 'restart_setup'
              bac.options[:atwhat]                   = 'Cluster'       if operation == 'restart_cluster'
              bac.options[:atwhat]                   = 'PostProcess'   if operation == 'restart_postprocess'
              bac.save
            else # old mechanism for all other operations, performed by a message to the Bourreau
              # Note: after refactoring in June 2024, at this point this should never be reached?!?
              bourreau.send_command_alter_tasks(oktasks, new_status,
                                               { :requester_user_id        => current_user.id,
                                                 :new_bourreau_id          => dup_bourreau_id,
                                                 :archive_data_provider_id => archive_dp_id
                                               }
                                              ) # TODO parse returned command object?
            end
            success_list += oktasks
          end
          skippedtasks = btasklist - oktasks
          skipped_list["Tasks have incompatible states"] = skippedtasks if skippedtasks.present?
        rescue => e
          failed_list[e.message] ||= []
          failed_list[e.message]  += btasklist
        end
      end # foreach bourreaux' tasklist

    # End of weird indentation

    # This may contain nothing at all if all work was done in background...
    results =  {
      :skipped_list => skipped_list,
      :success_list => success_list,
      :failed_list  => failed_list,
    }

    return results
  end



  #####################################################################
  # Zenodo Publishing Actions
  #####################################################################

  # GET /tasks/:id/zenodo
  def zenodo #:nodoc:
    task_id     = params[:id]
    @task = current_user.available_tasks.find(task_id)

    # Check stuff
    cb_error "This task doesn't have the capabilities to publish to Zenodo.", :redirect => task_path(@task) unless
      @task.has_zenodo_capabilities?
    cb_error "You have not configured any Zenodo token in your account.", :redirect => task_path(@task) unless
      current_user.has_zenodo_credentials?
    cb_error "This task is archived, unarchived it first.", :redirect => task_path(@task) if
      @task.archived_status
    cb_error "This task is on an execution server that is unavailable.", :redirect => task_path(@task) unless
      @task.bourreau.is_alive?
    cb_error "You have to be the owner of the task to publish its outputs.", :redirect => task_path(@task) if
      current_user.id != @task.user_id

    # Any of these can be nil
    combined_dep_id   = @task.zenodo_deposit_id.presence # 'main-1234' or 'sandbox-1234'
    zsite, deposit_id = (combined_dep_id || "").split("-") # "main", "1234"

    # What files this task is supposed to upload
    zenodo_userfile_ids = @task.zenodo_outputfile_ids
    @zenodo_userfiles   = zenodo_userfiles_from_ids(zenodo_userfile_ids)
    if (@zenodo_userfiles.compact.empty?)
      cb_error "This task doesn't seem to have produced any publishable outputs.", :redirect => task_path(@task)
    end

    # Figure out at what 'step' of the process we are at:
    #
    #   1- Nothing done yet, so present the form for the user
    #   2- A deposit has been created on zenodo and files are being uploaded in background
    #   3- A deposit has been created on zenodo and files have finished uploading
    #   4- The deposit has been published by the user
    #
    # All these steps can be repeated more than once: when
    # the deposits are on the zenodo sandbox (any number of times)
    # or the main zenodo (only once). This is tracked by a variable
    # 'zsite' with values of 'main' or 'sandbox', and it usually
    # prefixes the value of the deposit ID in the CbrainTask and Userfile
    # attribute :zenodo_deposit_id . See @combined_dep_id above.

    # For steps 2, 3 and 4: find the zenodo deposit from Zenodo
    if deposit_id.present?
      init_zenodo_client(zsite)
      @zenodo_deposit = find_existing_deposit(deposit_id)
      if @zenodo_deposit.nil?
        # Oh? It must have been deleted? TODO: check if still the case after published?
        message = "Warning: Deposit ##{deposit_id} (#{zsite}) has disappeared from Zenodo."

        # Zap task's deposit info
        @task.zenodo_deposit_id = nil
        @task.save!
        @task.addlog(message)

        # Zap userfiles' deposit info
        @zenodo_userfiles.compact.each do |userfile|
          next unless userfile.zenodo_deposit_id == combined_dep_id
          userfile.zenodo_deposit_id = nil
          userfile.save!
          userfile.addlog(message)
        end

        flash.now[:notice] = message
        combined_dep_id = zsite = deposit_id = nil # so we enter step 1 code below
      else # Record DOI if needed
        if @zenodo_deposit.submitted && @zenodo_deposit.metadata.doi.present?
          zenodo_doi = @zenodo_deposit.metadata.doi
          if @task.zenodo_doi.blank?
            @task.update_column(:zenodo_doi, zenodo_doi)
            @task.addlog("Zenodo DOI added: #{zenodo_doi}")
          end
          @zenodo_userfiles.compact.each do |userfile|
            next if userfile.zenodo_doi.present?
            userfile.update_column(:zenodo_doi, zenodo_doi)
            userfile.addlog("Zenodo DOI added: #{zenodo_doi}")
          end
        end
      end
    end

    # Step 1: ask the task for what we need to build a new zenodo deposit
    # This sets up what's needed to render the initial form.
    if combined_dep_id.blank?
      @zenodo_deposit  = @task.base_zenodo_deposit
      @zenodo_metadata = @zenodo_deposit.metadata || ZenodoClient::DepositMetadata.new

      # Adjustments: creators
      author = current_user.full_name.sub(/\s+(\S+)\s*$/,"")
      last   = Regexp.last_match.try(:[],1)
      author = "#{last}, #{author}" if last.present?
      @zenodo_metadata.creators ||= []
      @zenodo_metadata.creators.unshift(ZenodoClient::Author.new( :name => author )) unless
        @zenodo_metadata.creators.any? { |a| a.name == author }
    end

    # All good for rendering the zenodo status page
    return # renders zenodo.html.erb

  end

  # POST /tasks/:id/create_zenodo
  def create_zenodo #:nodoc:
    task_id = params[:id]
    @task   = current_user.available_tasks.find(task_id)

    if @task.zenodo_doi.present?
      cb_error "A deposit has already been published.", :redirect => zenodo_task_path(@task)
    elsif @task.zenodo_deposit_id.present?
      cb_error "A deposit has already been created.", :redirect => zenodo_task_path(@task)
    end

    @zenodo_deposit     = ZenodoClient::Deposit.new(         zenodo_deposit_params.to_h          )
    @zenodo_metadata    = ZenodoClient::DepositMetadata.new( zenodo_deposit_metadata_params.to_h )
    zenodo_userfile_ids = @task.zenodo_outputfile_ids
    @zenodo_userfiles   = zenodo_userfiles_from_ids(zenodo_userfile_ids)

    # Adjustements: related files. All outputs that are already present
    # with another DOI are just refered to as such.
    related = @zenodo_userfiles
      .select { |u| u.zenodo_doi.present? }
      .map    { |u| ZenodoClient::RelatedIdentifier.new(:identifier => u.zenodo_doi, :relation => 'hasPart') }
    if related.present?
      @zenodo_metadata.related_identifiers ||= []
      @zenodo_metadata.related_identifiers  += related
    end

    # Validate the deposit structure.
    # We can't validate the metadata struct because even though
    # many fields are mandatory, they can be left blank during the
    # initial creation.
    if (! @zenodo_deposit.valid?)
      flash.now[:error] = "The deposit information seems invalid."
      render :zenodo
      return
    end

    # Create it on zenodo
    zsite       = init_zenodo_client(params[:zsite]) # 'main' or 'sandbox'
    new_deposit = create_initial_deposit(@zenodo_deposit, @zenodo_metadata)

    # Record in task
    @task.zenodo_deposit_id = "#{zsite}-#{new_deposit.id}"
    @task.save_with_logging(current_user, [ :zenodo_deposit_id ])

    # Upload files and data in background
    background_upload_task_info_to_deposit(new_deposit, @task, @zenodo_userfiles) # forks

    redirect_to :action => :zenodo

  rescue ZenodoClient::ApiError => ex
    if ex.message == 'FORBIDDEN'
      cb_error "Cannot create the initial Zenodo deposit. It is likely your token is invalid or it doesn't have the proper scopes. Try using a new token.", :redirect => task_path(@task)
    else
      raise ex
    end
  end

  # This action resets a task that has been prepared or published
  # to the zenodo sandbox, so it can be either published again on
  # the sandbox or published to the official zenodo site. Once
  # published on the official zenodo site, it can't be reset.
  def reset_zenodo
    task_id = params[:id]
    @task   = current_user.available_tasks.find(task_id)

    if @task.zenodo_doi.present? && ! @task.zenodo_doi.starts_with?(ZenodoHelper::ZenodoSandboxDOIPrefix)
      cb_error "This task's outputs have already been published and we cannot reset its publication state any more."
    end

    # Remember original IDs
    orig_deposit_id         = @task.zenodo_deposit_id
    orig_doi                = @task.zenodo_doi

    # Reset task
    @task.zenodo_deposit_id = nil
    @task.zenodo_doi        = nil
    @task.save_with_logging(current_user, [ :zenodo_deposit_id, :zenodo_doi ])

    # Reset all files
    zenodo_userfile_ids = @task.zenodo_outputfile_ids
    @zenodo_userfiles   = zenodo_userfiles_from_ids(zenodo_userfile_ids)
    @zenodo_userfiles.compact.each do |userfile|
      next if userfile.zenodo_doi.present? && ! userfile.zenodo_doi.starts_with?(ZenodoHelper::ZenodoSandboxDOIPrefix)
      userfile.zenodo_deposit_id = nil if userfile.zenodo_deposit_id == orig_deposit_id
      userfile.zenodo_doi        = nil if userfile.zenodo_doi        == orig_doi
      userfile.save_with_logging(current_user, [ :zenodo_deposit_id, :zenodo_doi ])
    end

    # Attempt to remove the deposit on Zenodo; if it's published
    # it will not be deleted no matter how much we try.
    zsite, deposit_id = (orig_deposit_id || "").split("-") # "main", "1234"
    init_zenodo_client(zsite)
    depo_api = ZenodoClient::DepositsApi.new
    depo_api.delete_deposit(deposit_id.to_i) rescue 'ignore'

    redirect_to :action => :zenodo
  end

  private

  # Returns a list of userfiles out of the
  # +ids+ ; nil elements are left in the array if
  # any id matches a missing file or a file not
  # accessible by the current user.
  def zenodo_userfiles_from_ids(ids) #:nodoc:
    ids.map do |id|
      Userfile
        .find_all_accessible_by_user(current_user)
        .where(:id => id)
        .first # we allow nils: it means the task returned an ID of a missing/unaccessible file
    end
  end

  def zenodo_server_by_zsite(zsite) #:nodoc:
    zsite == 'main' ?
      'zenodo.org'  :
      'sandbox.zenodo.org'
  end

  def token_by_zsite(zsite) #:nodoc:
    token = zsite == 'main'             ?
      current_user.zenodo_main_token    :
      current_user.zenodo_sandbox_token
    token.presence.try(:strip)
  end

  def init_zenodo_client(zsite) #:nodoc:
    zsite  = zsite == 'main' ? 'main' : 'sandbox' # sanitize
    token  = token_by_zsite(zsite)
    server = zenodo_server_by_zsite(zsite)
    ZenodoClient.configure do |config|
      config.api_key['access_token'] = token
      config.host                    = server
      #config.debugging               = true # will print info on stdout; WARNING binary junk!
    end
    # Let's be nice with the poor sysadmins who look at logs
    ZenodoClient::ApiClient.default.user_agent =
      "CBRAIN/#{CBRAIN::CBRAIN::CBRAIN_StartTime_Revision}/ZenodoClient/#{ZenodoClient::VERSION}"
    zsite
  end

  def find_existing_deposit(deposit_id) #:nodoc:
    depo_api = ZenodoClient::DepositsApi.new
    deposit  = depo_api.get_deposit(deposit_id.to_i)
    deposit
  rescue ZenodoClient::ApiError => ex
    return nil if ex.message == 'GONE'
    raise
  end

  def create_initial_deposit(deposit, metadata) #:nodoc:
    # Create the Deposit
    depo_api    = ZenodoClient::DepositsApi.new
    new_deposit = depo_api.create_deposit(deposit)

    # Add metadata
    nested               = ZenodoClient::NestedDepositMetadata.new
    nested.metadata      = metadata
    metadata.upload_type = 'dataset'
    deposit              = depo_api.put_deposit(new_deposit.id, nested)

    # Return the deposit
    deposit
  end

  def background_upload_task_info_to_deposit(deposit, task, userfiles) #:nodoc:

    # Select which files to upload
    userfiles = userfiles
      .compact
      .reject { |u| u.zenodo_deposit_id.present? }
      .reject { |u| u.zenodo_doi.present? }

    # Note: because of a problem with libcurl not being thread-safe and fork-safe,
    # I have for the moment disabled the ability to upload files in background;
    # instead the "1.times" block below will upload in synchronous mode, blocking
    # the user interface.... :-(
    #
    # Attempts made to solve this:
    #   Typhoeus::Pool.easies.each(&:reset)
    #   Typhoeus::Pool.clear
    #
    #   Ethon::Curl.cleanup (before and/or after fork)
    #   Ethon::Curl.init
    #
    #   Ethon::Curl.global_cleanup (before and/or after fork)
    #   Ethon::Curl.global_init(0x03) # not needed, Ethon::Easy.new does it already

    #CBRAIN.spawn_with_active_records_if(userfiles.present?, current_user, 'UploadToZenodo') do
    1.times do # non-forking alternative to spawn block

      errors   = [] # array of one line text messages
      uploaded = [] # array of one line text messages

      # Real userfiles
      userfiles.each_with_index do |userfile,idx|
        begin
          #Process.setproctitle "ZenodoUpload ID=#{userfile.id} #{idx+1}/#{userfiles.size}"
          upload_userfile_to_deposit(deposit, userfile)
          uploaded << "File: #{userfile.name} (ID=#{userfile.id})"
        rescue => ex
          errors   << "File: #{userfile.name} (ID=#{userfile.id}): #{ex.class}: #{ex.message}"
        end
      end

      # Contact bourreau and get task's out, err and script
      #Process.setproctitle "ZenodoUpload Task Info ID=#{task.id}"
      task.capture_job_out_err(task.run_number,100_000,100_000) rescue nil # nums are number of lines

      # Captured special data
      pretty_json_task = JSON.pretty_generate(task.for_api)
      runtime_info     = JSON.pretty_generate(task.struct_runtime_info)
      boutiques_path   = task.class.generated_from.descriptor_path rescue nil
      boutiques_json   = boutiques_path.to_s.ends_with?(".json") ? File.read(boutiques_path) : nil
      er1 = upload_text_data_to_deposit(deposit, task.script_text,    "main_cbrain_script-#{task.run_id}.sh")
      er2 = upload_text_data_to_deposit(deposit, task.cluster_stdout, "captured_stdout-#{task.run_id}.log"  )
      er3 = upload_text_data_to_deposit(deposit, task.cluster_stderr, "captured_stderr-#{task.run_id}.log"  )
      er4 = upload_text_data_to_deposit(deposit, task.getlog,         "cbrain_log-#{task.run_id}.log"       )
      er5 = upload_text_data_to_deposit(deposit, pretty_json_task,    "cbrain_task-#{task.run_id}.json"     )
      er6 = upload_text_data_to_deposit(deposit, runtime_info,        "runtime_info-#{task.run_id}.json"    )
      er7 = upload_text_data_to_deposit(deposit, boutiques_json,      "boutiques-#{task.run_id}.json"       ) if boutiques_json
      [ er1, er2, er3, er4, er5, er6, er7 ].each { |er| errors << er if er.present? }

      if errors.present?
        Message.send_message(current_user,
          :message_type  => 'error',
          :header        => "Could not send a file to Zenodo",
          :description   => "Some errors occurred while sending files to Zenodo",
          :variable_text => "For #{view_pluralize(errors.size,"file")}:\n" + errors.join("\n")
        )
      end

      if uploaded.present?
        Message.send_message(current_user,
          :message_type  => 'notice',
          :header        => "Uploaded files to Zenodo",
          :description   => "These files were uploaded to Zenodo",
          :variable_text => "For #{view_pluralize(uploaded.size,"file")}:\n" + uploaded.join("\n")
        )
      end
    end
  end

  def upload_userfile_to_deposit(deposit, userfile) #:nodoc:
    is_col = userfile.is_a?(FileCollection)

    # Identify the content
    userfile.sync_to_cache
    content_path = userfile.cache_full_path
    content_name = userfile.name
    content_path = create_tmp_tar_for_filecollection(userfile) if is_col
    content_name = userfile.name + ".tar.gz"                   if is_col

    # Upload
    dep_file = upload_file_content_to_deposit(deposit.id, content_path, content_name)

    # Log info in userfile
    zsite = deposit.links[:self].to_s =~ /sandbox/ ? 'sandbox' : 'main' # one way to guess
    userfile.addlog("Uploaded to Zenodo in Deposit #{deposit.id} with ID #{dep_file.id}")
    userfile.zenodo_deposit_id = "#{zsite}-#{deposit.id}"
    userfile.save
  ensure
    File.unlink(content_path) if is_col && content_path.present? && File.file?(content_path)
  end

  def upload_text_data_to_deposit(deposit, text, filename) #:nodoc:
    cb_error "No content provided" if text.blank?

    # Prep temp file
    content_path = "/tmp/#{filename}.#{rand(1000000)}"
    File.open(content_path, "w:BINARY") { |fh| fh.write(text) }

    # Upload
    upload_file_content_to_deposit(deposit.id, content_path, filename)

    return nil # it means all is OK
  rescue => ex
    return "File: #{filename}: #{ex.class}: #{ex.message}"
  ensure
    File.unlink(content_path) rescue nil
  end

  # This assumes filecollection has already been sychronized
  def create_tmp_tar_for_filecollection(filecollection) #:nodoc:
    cache   = filecollection.cache_full_path
    tmpbase = "/tmp/#{filecollection.name}-#{rand(1000000)}.tar.gz"
    ret     = system "cd #{cache.parent.to_s.bash_escape} && tar -czf #{tmpbase} #{filecollection.name.bash_escape}"
    cb_error "Cannot create tmp tar file for FileCollection ##{filecollection.id}" unless ret
    tmpbase
  end

  def upload_file_content_to_deposit(deposit_id, file_path, filename) #:nodoc:
    # Upload
    filesapi = ZenodoClient::FilesApi.new
    file_h   = File.open(file_path,"r:BINARY")
    dep_file = filesapi.create_file(deposit_id, file_h, filename)
    file_h.close rescue true # hope it's ok

    # Rename? Sometimes necessary
    if dep_file.filename != filename
      dep_file.filename = filename
      filesapi.update_file(deposit_id, dep_file.id, dep_file)
    end

    dep_file
  end



  #####################################################################
  # Private Methods For Form Support
  #####################################################################

  private

  def task_params #:nodoc:
    task_attr = params.require_as_params(:cbrain_task).permit(
      :user_id, :group_id, :description,
      :bourreau_id, :tool_config_id,
      :batch_id,
      :results_data_provider_id, :params => {}
    )
    # There are way too many 'params' in the next bit of code. Two different
    # concepts with the same name... :-(
    task_params = params.require_as_params(:cbrain_task).require_as_params(:params)
    task_params.permit!
    task_attr[:params] = task_params
    task_attr
  end

  def zenodo_deposit_params #:nodoc:
    zen_params = params.require_as_params(:zenodo_deposit).permit(
      # :title # for the moment just that
    )
    zen_params
  end

  def zenodo_deposit_metadata_params #:nodoc:
    zen_meta_params = params.require_as_params(:zenodo_deposit_metadata).permit(
      :title, :description, :community, :creators => [:name]
    )
    zen_meta_params[:creators] ||= []
    zen_meta_params[:creators].reject! { |creator| creator[:name].blank? }
    zen_meta_params
  end



  #####################################################################
  # Task Creation Private Methods
  #####################################################################

  private

  # Part of the create() process for a task
  #
  # Code extracted from the old monolithic 'create'
  def create_initial_task_from_form(new_task_info, tool_id = nil) #:nodoc:

    # Safety check
    cb_error "Got argument that is not a ActionController::Parameters set with permitted=true..." unless
      new_task_info.is_a?(ActionController::Parameters) and new_task_info.permitted?

    # For historical reasons, the web interface sends both a tool_id and a tool_config_id.
    # Only the tool_config_id is really necessary, as itself the tool_config object supplies
    # the tool_id and the bourreau_id.
    # For support with the external APIs, we'll try to guess missing values if we
    # only receive a tool_config_id.
    params_tool_config_id = new_task_info[:tool_config_id] # can be nil
    tool_config           = ToolConfig.find(params_tool_config_id) rescue nil
    tool_config           = nil unless tool_config && tool_config.can_be_accessed_by?(current_user) &&
                             tool_config.bourreau_and_tool_can_be_accessed_by?(current_user)
    if tool_config
      params[:tool_id]            = tool_config.tool_id     # replace whatever was there or not, tool_id is not CbrainTask parameters
      new_task_info[:bourreau_id] = tool_config.bourreau_id # replace whatever was there or not
    else
      new_task_info[:tool_config_id] = nil # ZAP value, it's incorrect; will likely cause a validation error later on.
    end

    # Validate the batch_id
    new_task_info[:batch_id] = nil unless
      new_task_info[:batch_id].present? &&
      current_user.cbrain_tasks.real_tasks.where(:id => new_task_info[:batch_id]).count == 1

    # A brand new task object!
    tool             = tool_config ? tool_config.tool : current_user.available_tools.where(:id => tool_id).first
    task_class       = tool_config ? tool_config.tool.cbrain_task_class : tool.cbrain_task_class
    task             = task_class.new(new_task_info)
    task.user_id   ||= current_user.id
    task.group_id  ||= current_assignable_group.id
    task.status      = "New" if task.status.blank? || task.status !~ /Standby/ # Standby is special.

    # Extract the Bourreau ID from the ToolConfig
    if tool_config && tool_config.bourreau
      task.bourreau = tool_config.bourreau
    else
      task.errors.add(:base, "Please select a Server and a Version for the tool.")
    end

    # Security checks
    task.user     = current_user           unless current_user.available_users.map(&:id).include?(task.user_id)
    task.group    = current_user.own_group unless current_user.assignable_group_ids.include?(task.group_id)

    # Log revision number of portal.
    task.addlog_current_resource_revision
    task.addlog_context(self,"Created by #{current_user.login}")

    return task
  end

  # Part of the create() process for a task
  #
  # Code extracted from the old monolithic 'create'
  def create_tasklist_from_initial_task(maintask) #:nodoc:

    messages = ""

    # Detect automatic parallelism support; in that case
    # the tasks are created in the 'Standby' state, then
    # passed to the CbrainTask::Parallelizer class to
    # launch (one or many) parallelizer objects too.
    parallel_size = nil
    prop_parallel = maintask.class.properties[:use_parallelizer] # true, or a number
    tc_ncpus      = maintask.tool_config.ncpus || 1
    if prop_parallel && (tc_ncpus > 1)
      if prop_parallel.is_a?(Integer) && prop_parallel > 1
        parallel_size = tc_ncpus < prop_parallel ? tc_ncpus : prop_parallel # min of the two
      else
        parallel_size = tc_ncpus
      end
      parallel_size = nil if parallel_size < 2 # no need then
    end

    # Disable parallelizer if no Tool object yet created.
    if parallel_size && ! CbrainTask::Parallelizer.tool
      parallel_size = nil
      messages += "Warning: parallelization cannot be performed until the admin configures a Tool for it.\n"
    end

    # Prepare final list of tasks; from the one maintask object we have,
    # we get a full array of clones of that task in tasklist
    tasklist,task_list_message = maintask.wrapper_final_task_list
    if task_list_message.present?
      messages += "\n" if messages.present?
      messages += task_list_message
    end

    # Spawn a background process to launch the tasks.
    # In case of API requests, we don't spawn.
    CBRAIN.spawn_with_active_records_if(! api_request?, :admin, "Spawn Tasks") do

      batch_id            = nil # all tasks will get the same batch_id ONCE the first task is saved.
      spawn_messages      = ""
      share_wd_Nid_to_tid = {} # a negative number -> task_id

      tasklist.each do |task|
        begin

          # Set initial status
          if parallel_size && task.class == maintask.class # Parallelize only tasks of same class as original
            if (task.status || 'New') !~ /New|Standby/ # making sure task programmer knows what he's doing
              raise ScriptError.new("Trying to parallelize a task, but the status was '#{task.status}' instead of 'New' or 'Standby'.")
            end
            task.status = "Standby" # force it there; the parallelizer with turn it back to 'New' later on
          else
            task.status = "New" if task.status.blank?
          end

          # Save task and records batch_id, and set of shared WD task IDs
          task.batch_id ||= batch_id # will be nil for the first task, but we'll reset it a bit later to a real ID
          share_wd_Nid = task.share_wd_tid # the negative number for the set of tasks sharing a workdir
          if share_wd_Nid.present? && share_wd_Nid <= 0
            task.share_wd_tid = share_wd_Nid_to_tid[share_wd_Nid] # will be nil for first task in set, which is OK
            task.save! # this sets batch_id if it's still nil, in an after_save() callback
            share_wd_Nid_to_tid[share_wd_Nid] ||= task.id # first task in group
          else
            task.save! # this sets batch_id if it's still nil, in an after_save callback
          end

          # First task in the batch is the one to determine the batch_id for the other tasks
          batch_id ||= task.batch_id

        rescue => ex
          spawn_messages += "This task #{task.name} seems invalid: #{ex.class}: #{ex.message}.\n"
        end
      end

      spawn_messages += maintask.wrapper_after_final_task_list_saved(tasklist)  # TODO check, use messages?

      # Create parallelizers, if needed
      if parallel_size
        paral_tasklist = tasklist.select { |t| t.class == maintask.class }
        paral_info = CbrainTask::Parallelizer.create_from_task_list(paral_tasklist, :group_size => parallel_size)
        paral_messages = paral_info[0] # [1] is an array of Parallelizers, [2] an array of single tasks.
        if paral_messages.present?
          spawn_messages += "\n" if spawn_messages.present?
          spawn_messages += paral_messages
        end
      end

      # Send a start worker command to each affected bourreau
      bourreau_ids = tasklist.map(&:bourreau_id)
      bourreau_ids.uniq.each do |bourreau_id|
        Bourreau.find(bourreau_id).send_command_start_workers rescue true
      end

      if spawn_messages.present?
        Message.send_message(current_user, {
          :header        => "Submitted #{tasklist.size} #{maintask.pretty_name} tasks; some messages follow.",
          :message_type  => :notice,
          :variable_text => spawn_messages
          }
        )
      end

    end # CBRAIN spawn_if block

    return tasklist,messages
  end

  # Some useful variables for the views for 'new' and 'edit'
  def initialize_common_form_values #:nodoc:

    # Find the list of Bourreaux that are both available and support the tool
    tool         = @task.tool
    bourreau_ids = tool.bourreaux.pluck(:id)
    bourreaux    = Bourreau.find_all_accessible_by_user(current_user).where( :online => true, :id => bourreau_ids ).all

    # Presets
    unless @task.class.properties[:no_presets]
      site_preset_tasks = []
      unless current_user.site.blank?
        manager_ids = current_user.site.managers.map(&:id)
        site_preset_tasks = CbrainTask.where( :status => 'SitePreset', :user_id => manager_ids )
      end
      own_preset_tasks = current_user.cbrain_tasks.where( :type => @task.class.to_s, :status => 'Preset' )
      @own_presets  = own_preset_tasks.collect  { |t| [ t.short_description, t.id ] }
      @site_presets = site_preset_tasks.collect { |t| [ "#{t.short_description} (by #{t.user.login})", t.id ] }
      @all_presets = []
      @all_presets << [ "Site Presets",     @site_presets ] if @site_presets.size > 0
      @all_presets << [ "Personal Presets", @own_presets  ] if @own_presets.size > 0
      @offer_site_preset = current_user.has_role? :site_manager
    end

    # Tool Configurations
    valid_bourreau_ids = bourreaux.index_by(&:id)
    valid_bourreau_ids = { @task.bourreau_id => @task.bourreau } if ! @task.new_record? # existing tasks have more limited choices.
    @tool_configs      = tool.tool_configs.all.to_a # all of them, too much actually
    @tool_configs.reject! do |tc|
      tc.bourreau_id.blank? ||
      ! valid_bourreau_ids[tc.bourreau_id] ||
      ! tc.can_be_accessed_by?(@task.user)
    end

  end

  # This method handle the logic of loading and saving presets.
  def handle_preset_actions #:nodoc:
    commit_name  = extract_params_key([ :load_preset, :delete_preset, :save_preset ], :whatewer)

    if commit_name == :load_preset
      preset_id = params[:load_preset_id] # used for delete too
      if (! preset_id.blank?) && preset = CbrainTask.where(:id => preset_id, :status => [ 'Preset', 'SitePreset' ]).first
        old_params = @task.params.clone
        @task.params         = preset.params
        @task.description    = @task.description || ""
        @task.description   += "\n\nDescription from preset configuration:\n\n#{preset.description}" if preset.description.present?
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

    if commit_name == :delete_preset
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

    if commit_name == :save_preset
      preset_name = params[:save_preset_name]
      preset = nil
      if ! preset_name.blank?
        preset = @task.dup # not .clone, as of Rails 3.1.10
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
      preset.bourreau_id          = 0   # convention: presets have bourreau id set to 0
      preset.batch_id             = nil
      preset.cluster_jobid        = nil
      preset.cluster_workdir      = nil
      preset.cluster_workdir_size = nil
      preset.prerequisites        = {}
      preset.rank                 = 0
      preset.level                = 0
      preset.run_number           = nil
      preset.share_wd_tid         = nil
      preset.workdir_archived     = false
      preset.workdir_archive_userfile_id = nil

      # Clean up params that are saved in the preset
      preset.wrapper_untouchable_params_attributes.each_key do |untouch|
        preset.params.delete(untouch) # no need to save these eh?
      end
      preset.wrapper_unpresetable_params_attributes.each_key do |unpreset|
        preset.params.delete(unpreset) # no need to save these either eh?
      end

      preset.save!

      flash[:notice] += "Saved preset '#{preset.short_description}'.\n"
    end
  end

  def resource_class #:nodoc:
    CbrainTask
  end

  # User task scope; tasks from +base+ currently visible/accessible to the
  # user, respecting project and bourreau restrictions.
  def user_scope(base)
    base
      .where(current_project ? { :group_id => current_project.id } : {})
      .where(
        :bourreau_id => Bourreau
          .find_all_accessible_by_user(current_user)
          .pluck("#{Bourreau.quoted_table_name}.id")
      )
  end

  # Custom filters scope; filtered list of tasks respecting currently active
  # custom filters. +base+ is expected to be the initial scope to apply custom
  # filters to. Requires a valid @scope object.
  def custom_scope(base)
    (@scope.custom[:custom_filters] ||= []).map!(&:to_i)
    (@scope.custom[:custom_filters] &= current_user.custom_filter_ids)
      .map { |id| TaskCustomFilter.find_by_id(id) }
      .compact
      .inject(base) { |scope, filter| filter.filter_scope(scope) }
  end

  # Combination of +user_scope+, +custom_scope+ and @scope object; returns a
  # scoped list of tasks fitlered/ordered by all three. +base+ is expected to
  # be the base scope to start with (passed directly to +user_scope+).
  # Requires a valid @scope object.
  def filtered_scope(base)
    @scope.apply(custom_scope(user_scope(base)))
  end

  public

  # Tasks-specific status filter; filter by a broad class of statuses: whether
  # or not a given task's status is within a specific class of statuses. For
  # example, the 'active' status class contains 'New', 'Standby', 'Configured',
  # etc.
  #
  # Note that this filter uses Scope::Filter's *value* attribute to hold the
  # status class to check against, and that the *attribute* attribute is
  # statically set to 'status' (as this filter will only ever filter on a task's
  # status).
  class StatusFilter < Scope::Filter
    # Status classes and their corresponding statuses (possible values for the
    # *value* attribute). These correspond to CbrainTask's status lists.
    StatusClasses = {
      'completed'  => CbrainTask::COMPLETED_STATUS,
      'running'    => CbrainTask::RUNNING_STATUS,
      'active'     => CbrainTask::ACTIVE_STATUS,
      'queued'     => CbrainTask::QUEUED_STATUS,
      'processing' => CbrainTask::PROCESSING_STATUS,
      'failed'     => CbrainTask::FAILED_STATUS
    }

    # Create a new blank StatusFilter. Only present to pre-set *attribute*.
    def initialize
      @attribute = 'status'
    end

    # Nice string representation of this filter for +pretty_scope_filter+.
    def to_s
      "Status: #{@value.to_s.humanize}"
    end

    # The methods below are StatusFilter specific versions of the Scope::Filter
    # interface. See Scope::Filter for more details on how these methods
    # operate and for detailed parameter information.

    # Type name to recognize this filter when in hash representation
    # (+type+ (+t+) key).
    def self.type_name
      't.sts'
    end

    # Apply this filter on +collection+, which is expected to be a tasks
    # model or scope or a collection of CbrainTask objects.
    #
    # Note that this filter is specific to CbrainTasks and will not operate
    # correctly with any other kind of object.
    def apply(collection)
      raise "no status to filter with" unless @value.present?

      statuses = StatusClasses[@value.to_s.downcase]

      # With a CbrainTask model (or scope)
      if (collection <= ApplicationRecord rescue nil)
        collection.where(:status => statuses)

      # With a Ruby Enumerable
      else
        collection.select { |t| statuses.include?(t.status) }
      end
    end

    # Check if this filter is valid (+apply+ can be used). A StatusFilter only
    # requires a valid *value* to be useable.
    def valid?
      @value.present?
    end

    # Create a new StatusFilter from a hash representation. The following keys
    # are recognized in +hash+:
    #
    # [+value+ or +v+]
    #  *value* attribute: a string or symbol denoting which set of statuses to
    #  match against; one of 'completed', 'running', 'active', 'queued',
    #  'processing' or 'failed'.
    #
    # Note that no other key from Scope::Filter's +from_hash+ is recognized.
    def self.from_hash(hash)
      return nil unless hash.is_a?(Hash)

      hash = hash.with_indifferent_access unless
        hash.is_a?(HashWithIndifferentAccess)

      filter = self.new
      value = (hash['value'] || hash['v']).to_s.downcase
      filter.value = value if StatusClasses.keys.include?(value)

      filter
    end

    # Convert this StatusFilter into a hash representation, doing the exact
    # opposite of +from_hash+.
    def to_hash(compact: false)
      hash = {
        'type'  => self.class.type_name,
        'value' => @value
      }

      compact ? self.class.compact_hash(hash) : hash
    end

    # Compact +hash+, a hash representation of StatusFilter (matching
    # +from_hash+'s structure).
    def self.compact_hash(hash)
      ViewScopes::Scope.generic_compact_hash(
        hash,
        {
          'type'  => 't',
          'value' => 'v',
        }
      )
    end
  end

end
