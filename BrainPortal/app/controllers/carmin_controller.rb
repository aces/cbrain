
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

# Controller implementing the CARMIN API.
#
# https://github.com/CARMIN-org/CARMIN-API
class CarminController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  CARMIN_revision = '0.3.1'

  api_available

  before_action :login_required, :except => [ :platform, :authenticate ]

  rescue_from CbrainCarminError, :with => :carmin_error_handler

  #############################################################################
  #
  # PLATFORM/AUTHENTICATION ACTIONS
  #
  #############################################################################

  # GET /platform
  #
  # Information about this CARMIN platform
  def platform #:nodoc:

    portal = RemoteResource.current_resource

    platform_properties = {
      "platformName": portal.name,
      "APIErrorCodesAndMessages": [
        {
          "errorCode": 0,
          "errorMessage": "All Is Well",
          "errorDetails": {
            "additionalProp1": {}
          }
        }
      ],
      "supportedModules": [
        "Processing", "Data", # "AdvancedData", "Management", "Commercial",
      ],
      "defaultLimitListExecutions": 0,
      "email":               (portal.support_email.presence || "unset@example.com"),
      "platformDescription": (portal.description.presence || ""),
      "minAuthorizedExecutionTimeout": 0,
      "maxAuthorizedExecutionTimeout": 0,
      "defaultExecutionTimeout": 0,
      "unsupportedMethods": [],
      "studiesSupport": true,
      "defaultStudy": "none",
      "supportedAPIVersion": "unknown",
      "supportedPipelineProperties": [ # update these in ToolConfig#to_carmin
        "tool_name",
        "exec_name",
        "version_name"
      ],
      "additionalProp1": {}
    }

    respond_to do |format|
      format.json { render :json => platform_properties }
    end
  end

  # POST /authenticate
  def authenticate #:nodoc:
    username = params[:username] # in CBRAIN we use 'login'
    password = params[:password]

    all_ok = eval_in_controller(::SessionsController) do
      user = User.authenticate(username,password) # can be nil if it fails
      create_from_user(user)
    end

    if ! all_ok
      head :unauthorized
      return
    end

    token = cbrain_session.try(:cbrain_api_token) || "badtoken"

    respond_to do |format|
      format.json do
        render :json => { :httpHeader => 'Authorization', :httpHeaderValue => "Bearer: #{token}" }
      end
    end
  end



  #############################################################################
  #
  # EXECUTIONS ACTIONS (CBRAIN'S tasks)
  #
  #############################################################################

  # GET /executions
  # I guess these are our tasks...
  def executions #:nodoc:
    group_name = params[:studyIdentifier].presence
    offset     = params[:offset].presence
    limit      = params[:limit].presence

    if group_name
      group = current_user.available_groups.where('groups.name' => group_name).first
    end

    tasks = current_user.available_tasks.real_tasks
    # Next line will purposely filter down to nothing if group_name is not a proper name for the user.
    tasks = tasks.where(:group_id => (group.try(:id) || 0)) if group_name
    tasks = tasks.order("created_at DESC, id DESC")
    tasks = tasks.offset(offset.to_i) if offset
    tasks = tasks.limit(limit.to_i)   if limit
    tasks = tasks.to_a

    respond_to do |format|
      format.json { render :json => tasks.map(&:to_carmin) }
    end
  end

  # GET /executions/:id
  def exec_show #:nodoc:
    task = current_user.available_tasks.real_tasks.find(params[:id])

    respond_to do |format|
      format.json { render :json => task.to_carmin }
    end
  end

  # GET /executions/count
  def exec_count #:nodoc:
    count = current_user.available_tasks.real_tasks.count

    respond_to do |format|
      format.text { render :plain => count } # what the CARMIN spec say we should return
      format.json { render :json  => count }
    end
  end

  # DELETE /executions/:id
  def exec_delete #:nodoc:
    del_files = params[:deleteFiles] || ""  # not used in CBRAIN
    del_files = del_files.to_s =~ /^(0|no|false)$/i ? false : del_files.present?
    task = current_user.available_tasks.real_tasks.find(params[:id])
    results = eval_in_controller(::TasksController) do
      apply_operation('delete', [ task.id ])
    end
    # We should check 'results' here and return something else
    # if the job couldn't be destroyed.
    results.nil? # just so 'ruby -c' doesn't complain.

    head :no_content # :no_content is 204, CARMIN wants that
  end

  # GET /executions/:id/results
  # We don't have an official way to link a task to its result files yet.
  def exec_results #:nodoc:
    task = current_user.available_tasks.real_tasks.find(params[:id])
    task.nil? # just so 'ruby -c' leaves us alone until we implement more code here

    respond_to do |format|
      format.json { render :json => [] }
    end
  end

  # GET /executions/:id/stdout
  def exec_stdout #:nodoc:
    task = current_user.available_tasks.real_tasks.find(params[:id])
    get_remote_task_info(task) # contacts Bourreau for the info

    respond_to do |format|
      format.text { render :plain => task.cluster_stdout }
    end
  end

  # GET /executions/:id/stderr
  def exec_stderr #:nodoc:
    task = current_user.available_tasks.real_tasks.find(params[:id])
    get_remote_task_info(task) # contacts Bourreau for the info

    respond_to do |format|
      format.text { render :plain => task.cluster_stderr }
    end
  end

  # PUT /executions/:id/play
  def exec_play #:nodoc:
    task = current_user.available_tasks.real_tasks.find(params[:id])
    task.nil? # just so 'ruby -c' leaves us alone until we implement more code here

    # Nothing to do: TODO decide if we want to restart tasks
    # that are completed, or terminated, etc.
    head :no_content # :no_content is 204, CARMIN wants that
  end

  # PUT /executions/:id/kill
  def exec_kill #:nodoc:
    task = current_user.available_tasks.real_tasks.find(params[:id])
    results = eval_in_controller(::TasksController) do
      apply_operation('Terminated', [ task.id ])
    end
    # We should check 'results' here and return something else
    # if the job couldn't be terminated.
    results.nil? # just so 'ruby -c' doesn't complain.

    # Nothing to do
    head :no_content # :no_content is 204, CARMIN wants that
  end

  # PUT /executions/:id
  def exec_update #:nodoc:
    task = current_user.available_tasks.real_tasks.find(params[:id])
    new_name    = params[:name]
    new_timeout = params[:timeout]

    # We actually don't do anything with the new name and timeout...
    # Names are immutable in CBRAIN, and there is no timeout either.
    task.nil? ; new_name.nil? ; new_timeout.nil? # just so 'ruby -c' says nothing

    # Nothing to do
    head :no_content # :no_content is 204, CARMIN wants that
  end

  # POST /executions
  def exec_create #:nodoc:
    tool_config_id = params[:pipelineIdentifier].presence
    task_params    = params[:inputValues].presence
    group_name     = params[:studyIdentifier].presence

    if group_name
      group = current_user.available_groups.where('groups.name' => group_name).first
    else
      group = current_user.own_group
    end

    post_params = ActionController::Parameters.new(
      {
        :user_id        => current_user.id,
        :group_id       => group.id,
        :tool_config_id => tool_config_id,
        :params         => task_params,
      }
    ).permit!

    task = eval_in_controller(::TasksController, :define_current_user => current_user) do
      create_initial_task_from_form(post_params)
    end

    messages = ""
    messages += task.wrapper_after_form

    tasklist,messages = eval_in_controller(::TasksController, :define_current_user => current_user) do
      create_tasklist_from_initial_task(task)
    end

    first_task = tasklist.first # too bad, CARMIN user won't ever see the full task list

    respond_to do |format|
      format.json { render :json => first_task.to_carmin }
    end
  end



  #############################################################################
  #
  # PIPELINES ACTIONS (CBRAIN's Tools and Tool_configs)
  #
  #############################################################################

  # GET /pipelines
  def pipelines #:nodoc:
    group_name = params[:studyIdentifier].presence
    property   = params[:property].presence
    propvalue  = params[:propvalue].presence

    if group_name
      group = current_user.available_groups.where('groups.name' => group_name).first
    end

    # Get all tool config; filter by group if user wants it so.
    mytcs = all_accessible_tool_configs(current_user)
    mytcs = mytcs.where(:group_id => (group.try(:id) || 0)) if group_name
    mytcs = mytcs.to_a.map(&:to_carmin)

    # Filter by carmin properties
    if property && propvalue
      mytcs.select! { |x| x.properties[property] == propvalue }
    end

    respond_to do |format|
      format.json { render :json => mytcs }
    end
  end

  # GET /pipelines/:id
  def pipelines_show #:nodoc:
    mytc = all_accessible_tool_configs(current_user).find(params[:id])

    respond_to do |format|
      format.json { render :json => mytc.to_carmin }
    end
  end

  # GET /pipelines/:id/boutiquesdescriptor
  def pipelines_boutiques #:nodoc:
    mytc = all_accessible_tool_configs(current_user).find(params[:id])

    # The descriptor is only available from CbrainTask classes
    # that have been generated from them.
    desc = mytc.cbrain_task_class.generated_from.descriptor rescue { :no_boutiques_descriptor => 'sorry' }

    respond_to do |format|
      format.json { render :json => desc }
    end
  end



  #############################################################################
  #
  # PATH ACTIONS (CBRAIN's Userfiles)
  #
  #############################################################################

  def path_show #:nodoc:
    path   = params[:path]
    action = params[:action2]
    dp     = CarminPathDataProvider.find_default_carmin_provider_for_user(current_user)
puts_magenta "DP=#{dp.inspect}"
    userfile,subpath = dp.carmin_path_to_userfile_and_subpath(path, current_user)
puts_red    "USERFILE=#{userfile.inspect}"
puts_yellow "SUBPATH=#{subpath.inspect}"
    return path_show_content(    userfile, subpath ) if action == 'content'
    return path_show_exists(     userfile, subpath ) if action == 'exists'
    return path_show_properties( userfile, subpath ) if action == 'properties'
    return path_show_list(       userfile, subpath ) if action == 'list'
    return path_show_md5(        userfile, subpath ) if action == 'md5'
    raise CbrainCarminError.new("Unknown action '#{action}'", :error_code => 12) # TODO assign/define error codes
  end

  def path_update #:nodoc:
  end

  def path_delete #:nodoc:
  end



  #############################################################################
  # Path handling utilities
  #############################################################################

  def path_show_content(userfile, subpath) #:nodoc:

    # Verifications
    carmin_error("Path doesn't exist: #{userfile.name}", Errno::ENOENT) if
      userfile.new_record?
    carmin_error("Not a directory: #{userfile.name}", Errno::ENOTDIR) if
      subpath.to_s.present? && userfile.is_a?(SingleFile)

    # Build final target
    userfile.sync_to_cache
    full_path = userfile.cache_full_path
    full_path = full_path + subpath if subpath.to_s.present?

    if File.file?(full_path.to_s)
      send_file full_path.to_s
      return
    end

    if File.directory?(full_path.to_s)
      stream_tar_directory(full_path)
      return
    end

    if subpath.to_s.present?
      carmin_error("Subpath #{subpath} doesn't exist inside #{userfile.name}", Errno::ENOENT)
    else
      carmin_error("File #{userfile.name} doesn't exist?!?",                   Errno::ENOENT)
    end

  end

  #############################################################################
  # Error handling
  #############################################################################

  def carmin_error(message, error_code = 0)
    error_code = error_code::Errno rescue error_code
    raise CbrainCarminError.new(
      message,
      :error_code   => error_code,
      :shift_caller => 2, # TODO check that this number is OK
    )
  end

  # Handles exceptions of class CbrainCarminError
  def carmin_error_handler(exception)
    error = {
      :errorCode    => (exception.error_code rescue 1),
      :errorMessage => exception.message,
      :errorDetails => {
        :ruby_class     => exception.class.to_s,
        :ruby_backtrace => [ 'Nope' ], # exception.backtrace,
      }
    }
    render :json => error, :status => :unprocessable_entity
  end



  #############################################################################
  private # Support methods
  #############################################################################

  # OMG I've been wondering how to do this for years, and now I know.
  # Even amazon AWS S3 doesn't have a streaming API like that.
  def stream_tar_directory(full_path) #:nodoc:
    send_file_headers!(
      :type     => 'application/octet-stream',
      :filename => full_path.basename.to_s + ".tar.gz",
    )
    tar_content_fh = IO.popen("cd #{full_path.parent};tar -czf - #{full_path.basename}","r")
    stream_out     = response.stream
    begin
      while block = tar_content_fh.read(64.kilobytes)
        stream_out.write block
        sleep 0.0001 # based on https://gist.github.com/njakobsen/6257887
      end
    rescue IOError
      # Client closed connection?
    ensure
      tar_content_fh.close rescue nil
      stream_out.close     rescue nil
    end
  end

  def get_remote_task_info(task) #:nodoc:
    task.capture_job_out_err() # PortalTask method: sends command to bourreau to get info
  rescue Errno::EADDRNOTAVAIL, Errno::ECONNREFUSED, EOFError, ActiveResource::ServerError, ActiveResource::TimeoutError, ActiveResource::MethodNotAllowed
    task.cluster_stdout = "Execution Server is DOWN!"
    task.cluster_stderr = "Execution Server is DOWN!"
  end

  # Messy utility, poking through layers. Tricky and brittle.
  def eval_in_controller(mycontroller, options={}, &block) #:nodoc:
    cb_error "Controller is not a ApplicationController?" unless mycontroller < ApplicationController
    cb_error "Block needed." unless block_given?
    context = mycontroller.new
    context.request = self.request
    if options.has_key?(:define_current_user)
      context.define_singleton_method(:current_user) { options[:define_current_user] }
    end
    context.instance_eval(&block)
  end

  # Just a really safe way to build a relation for all them tool_configs.
  def all_accessible_tool_configs(user = current_user) #:nodoc:
    # Tools
    tids = Tool.find_all_accessible_by_user(user).pluck(:id)
    # Bourreaux
    bids = Bourreau.find_all_accessible_by_user(user).pluck(:id)
    # ToolConfig
    tcs  = ToolConfig.find_all_accessible_by_user(user).where(:tool_id => tids, :bourreau_id => bids)

    return tcs
  end

end
