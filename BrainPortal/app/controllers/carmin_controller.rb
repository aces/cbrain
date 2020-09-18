
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

  skip_before_action :verify_authenticity_token
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

    all_ok, new_cb_session = eval_in_controller(::SessionsController) do
      user = User.authenticate(username,password) # can be nil if it fails
      ok   = create_from_user(user, 'CARMIN')
      [ok, cbrain_session]
    end
    @cbrain_session = new_cb_session # crush the session object that was created for the CarminController

    if ! all_ok
      head :unauthorized
      return
    end

    token = cbrain_session.try(:cbrain_api_token) || "badtoken"

    respond_to do |format|
      format.json do
        render :json => { :httpHeader => 'Authorization', :httpHeaderValue => "Bearer #{token}" }
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
      group = current_user.assignable_groups.where('groups.name' => group_name).first
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
      group = current_user.assignable_groups.where('groups.name' => group_name).first
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
      group = current_user.viewable_groups.where('groups.name' => group_name).first
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
    action = request.query_parameters[:action] # Can't use params[:action], it's used by Rails
    dp     = find_default_carmin_provider_for_user(current_user)
    userfile,subpath = carmin_path_to_userfile_and_subpath(path, current_user, dp)

    # Verifications
    carmin_error("Path doesn't exist: #{userfile.name}", Errno::ENOENT) if
      userfile.new_record? && action != 'exists'
    carmin_error("Not a directory: #{userfile.name}", Errno::ENOTDIR) if
      subpath.to_s.present? && userfile.is_a?(SingleFile)

    # Sub actions
    return path_show_content(    userfile, subpath ) if action == 'content'
    return path_show_exists(     userfile, subpath ) if action == 'exists'
    return path_show_properties( userfile, subpath ) if action == 'properties'
    return path_show_list(       userfile, subpath ) if action == 'list'
    return path_show_md5(        userfile, subpath ) if action == 'md5'

    carmin_error("Unknown action '#{action}'", Errno::EINVAL)
  end

  def path_create #:nodoc:
    path   = params[:path]

    dp     = find_default_carmin_provider_for_user(current_user)
    userfile,subpath = carmin_path_to_userfile_and_subpath(path, current_user, dp)

    carmin_error("Not a directory: #{userfile.name}", Errno::ENOTDIR) if
      subpath.to_s.present? && (userfile.is_a?(SingleFile) || userfile.new_record?)

    content_type = request.content_type
    if content_type == 'application/carmin+json'
      params.merge!(JSON.parse(request.raw_post)) # because Rails won't do it with content-type 'carmin+json'
      fileaction = params[:type]
      content    = params[:base64Content]
      carmin_error('Missing/bad type',     Errno::EINVAL) if fileaction.blank? || fileaction.to_s !~ /\A(File|Archive)\z/
      carmin_error('Missing file content', Errno::EINVAL) if content.nil?
      content    = Base64.decode64(content) rescue nil
      carmin_error('Bad Base64 content',   Errno::EINVAL) if content.nil?
    else
      fileaction = 'File'
      content    = request.raw_post
      if content.nil? || content.size == 0
        fileaction = 'Mkdir' # what a stupid convention
      end
    end

    path_create_mkdir(   userfile, subpath         ) if fileaction == 'Mkdir'
    path_create_file(    userfile, subpath, content) if fileaction == 'File'
    path_create_archive( userfile, subpath, content) if fileaction == 'Archive'

    userfile = Userfile.find(userfile.id) # reload so we get proper type
    return path_show_properties(userfile, subpath, :created)
  end

  def path_delete #:nodoc:
    path   = params[:path]

    dp     = find_default_carmin_provider_for_user(current_user)
    userfile,subpath = carmin_path_to_userfile_and_subpath(path, current_user, dp)

    carmin_error("Not a directory: #{userfile.name}", Errno::ENOTDIR) if
      userfile.new_record? ||
      (subpath.to_s.present? && ! userfile.is_a?(FileCollection))

    # Check to delete userfile outright
    if subpath.to_s.blank?
      userfile.destroy
    else # Delete part of a file collection
      userfile.sync_to_cache
      full_path, _ = check_filecollection_structure_exists(userfile, subpath)
      carmin_error("Entry doesn't exist: #{userfile.name}/#{subpath}", Errno::ENOENT) unless
        File.exists?(full_path.to_s)
      FileUtils.remove_dir(full_path.to_s, true)
      userfile.cache_is_newer
      userfile.sync_to_provider
    end

    head :no_content
  end



  #############################################################################
  #
  # END OF MAIN CARMIN API ACTIONS
  #
  #############################################################################



  #############################################################################
  # Path handling utilities: PATH SHOW
  #############################################################################

  def path_show_content(userfile, subpath) #:nodoc:

    # Build final target
    userfile.sync_to_cache
    full_path = userfile.cache_full_path
    full_path = full_path + subpath if subpath.to_s.present?

    if File.file?(full_path.to_s)
      send_file full_path.to_s
      return
    end

    if File.directory?(full_path.to_s)
      stream_tar_directory full_path
      return
    end

    if subpath.to_s.present?
      carmin_error("Subpath #{subpath} doesn't exist inside #{userfile.name}", Errno::ENOENT)
    else
      carmin_error("File #{userfile.name} doesn't exist?!?",                   Errno::ENOENT)
    end

  end

  def path_show_exists(userfile, subpath) #:nodoc:
    exists = false

    if userfile.new_record?
      exists = false
    elsif userfile.is_a?(SingleFile)
      exists = true # checking a SingleFile; no FS check
    elsif subpath.to_s.blank?
      exists = true # checking the root of a FileCollection; no FS check
    else # checking a component inside a FileCollection; FS check needed
      userfile.sync_to_cache
      full_path = userfile.cache_full_path + subpath
      exists = File.exists? full_path.to_s
    end

    respond_to do |format|
      format.json { render :json => { :exists => exists } }
    end
  end

  def path_show_properties(userfile, subpath, http_status = :ok ) #:nodoc:
    relpath      = Pathname.new(userfile.name) + subpath
    size         = userfile.size
    is_directory = userfile.is_a?(FileCollection)
    updated_at   = userfile.updated_at

    if is_directory && subpath.to_s.present?
      userfile.sync_to_cache
      content_path = userfile.cache_full_path + subpath
      stat         = File.lstat(content_path.to_s) rescue nil
      if ! stat
        carmin_error("Subpath #{subpath} doesn't exist inside #{userfile.name}", Errno::ENOENT)
      end
      is_directory = stat.directory?
      size         = is_directory ? nil : stat.size
      updated_at   = stat.mtime
    end

    respond_to do |format|
      format.json {
        render :json => {
                 :platformPath         => relpath.basename.to_s,
                 :lastModificationDate => updated_at.to_i,
                 :isDirectory          => is_directory,
                 :size                 => size,
               },
               :status => http_status
        }
    end
  end

  def path_show_list(userfile, subpath) #:nodoc:

    carmin_error("Not a directory: #{userfile.name}", Errno::ENOTDIR) if
      userfile.is_a?(SingleFile)

    userfile.sync_to_cache
    content_path = userfile.cache_full_path + subpath
    carmin_error("Subpath #{subpath} doesn't exist inside #{userfile.name}", Errno::ENOENT) if
      ! File.directory?(content_path.to_s)

    # Scan and build JSON path objects
    paths = Dir.open(content_path.to_s).sort.map do |entry|
      next nil if entry == '.' || entry == '..'
      stat = File.lstat((content_path + entry).to_s)
      {
        :platformPath         => entry,
        :lastModificationDate => stat.mtime.to_i,
        :isDirectory          => stat.directory?,
        :size                 => stat.directory? ? nil : stat.size,
      }
    end.compact

    respond_to do |format|
      format.json { render :json => paths }
    end
  end

  def path_show_md5(userfile, subpath) #:nodoc:
    carmin_error("Not a directory: #{userfile.name}", Errno::ENOTDIR) if
      userfile.is_a?(SingleFile) && subpath.to_s.present?

    userfile.sync_to_cache
    content_path = userfile.cache_full_path + subpath

    carmin_error("Subpath #{subpath} is not a file inside #{userfile.name}", Errno::ENOENT) if
      ! File.file?(content_path.to_s)

    md5command =
      case CBRAIN::System_Uname
      when /Linux/i
        "md5sum"
      when /Darwin/i
        "md5"
      else
        "md5sum" # hope it works
      end

    md5 = IO.popen("#{md5command} < #{content_path.to_s.bash_escape}","r") { |fh| fh.read }
    md5 = Regexp.last_match[1] if md5.present? && md5.match(/\b([0-9a-fA-F]{32})\b/)

    carmin_error("Can't compute MD5 for path #{Pathname.new(userfile.name) + subpath}", Errno::EIO) if
      md5.blank? || md5.size != 32

    respond_to do |format|
      format.json { render :json => { :md5 => md5 } }
    end
  end



  #############################################################################
  # Path handling utilities: PATH CREATE
  #############################################################################

  def path_create_mkdir(userfile, subpath) #:nodoc:
    if subpath.to_s.blank?
      path_create_mkdir_base_filecollection(userfile)
    else
      path_create_mkdir_in_collection(userfile, subpath)
    end
  end

  # If we have no subpath, we're creating a base FileCollection
  def path_create_mkdir_base_filecollection(userfile) #:nodoc:
    carmin_error("Directory exists: #{userfile.name}", Errno::EEXIST) if ! userfile.new_record?
    userfile.type = FileCollection if userfile.class == Userfile # exact comparison
    userfile.save!
    userfile = FileCollection.find(userfile.id) # reload with proper type
    userfile.cache_prepare
    Dir.mkdir(userfile.cache_full_path.to_s)
    userfile.sync_to_provider
  end

  # Create a subdirectory in the FileCollection
  def path_create_mkdir_in_collection(userfile, subpath) #:nodoc:
    userfile.sync_to_cache
    full_path, _ = check_filecollection_structure_exists(userfile, subpath)
    carmin_error("Entry exists: #{full_path.basename}", Errno::EEXIST) if
      File.exists?(full_path.to_s)
    Dir.mkdir(full_path.to_s)
    userfile.sync_to_provider
  end

  def path_create_file(userfile, subpath, content) #:nodoc:
    if subpath.to_s.present?
      return path_create_file_in_collection(userfile, subpath, content)
    else
      return path_create_file_as_singlefile(userfile, content)
    end
  end

  def path_create_file_as_singlefile(userfile, content) #:nodoc:
    userfile.type = SingleFile if userfile.class == Userfile # exact comparison
    userfile.save!
    userfile = SingleFile.find(userfile.id) # reload with proper type
    userfile.cache_writehandle do
      File.write(userfile.cache_full_path.to_s, content)
    end # sync_to_provider automatically called
  end

  def path_create_file_in_collection(userfile, subpath, content) #:nodoc:
    userfile.sync_to_cache
    full_path, _ = check_filecollection_structure_exists(userfile, subpath)
    carmin_error("Entry exists: #{full_path.basename}", Errno::EEXIST) if
      File.exists?(full_path.to_s)
    userfile.cache_writehandle do
      File.write(full_path.to_s, content)
    end # sync_to_provider automatically called
  end

  def path_create_archive(userfile, subpath, archive) #:nodoc:
    if subpath.to_s.present?
      return path_create_archive_in_collection(userfile, subpath, archive)
    else
      return path_create_archive_as_collection(userfile, archive)
    end
  end

  def path_create_archive_as_collection(userfile, archive) #:nodoc:
    carmin_error("Entry exists: #{userfile.name}", Errno::EEXIST) if
      userfile.is_a?(SingleFile)
    carmin_error("Entry doesn't exist: #{userfile.name}", Errno::ENOENT) unless
      userfile.is_a?(FileCollection) && ! userfile.new_record?

    userfile.sync_to_cache
    full_path = userfile.cache_full_path
    capt = extract_archive_in_collection(userfile, full_path, archive)
    carmin_error("Cannot extract archive", Errno::EINVAL) if capt.present?
  end

  def path_create_archive_in_collection(userfile, subpath, archive) #:nodoc:
    userfile.sync_to_cache
    full_path, _ = check_filecollection_structure_exists(userfile, subpath)
    carmin_error("Entry doesn't exist: #{userfile.name}/#{subpath}", Errno::ENOENT) unless
      File.directory?(full_path.to_s)

    capt = extract_archive_in_collection(userfile, full_path, archive)
    carmin_error("Cannot extract archive", Errno::EINVAL) if capt.present?
  end



  #############################################################################
  # General Error handling
  #############################################################################

  def carmin_error(message, error_code = 0)
    error_code = error_code::Errno rescue error_code
    raise CbrainCarminError.new(
      message,
      :error_code   => error_code,
      :shift_caller => 3,
    )
  end

  # Handles exceptions of class CbrainCarminError
  def carmin_error_handler(exception)

    error = {
      :errorCode    => (exception.error_code rescue 1),
      :errorMessage => exception.message,
      :errorDetails => {
        :ruby_class     => exception.class.to_s,
        :ruby_backtrace => Rails.backtrace_cleaner.clean(exception.backtrace),
      }
    }

    plain_text = <<-ERROR # TODO add more details? Backtrace?
    #{exception.class} #{exception.message}
    ERROR

    respond_to do |format|
      format.json { render :json  => error,      :status => :unprocessable_entity }
      format.text { render :plain => plain_text, :status => :unprocessable_entity }
      format.html { render :plain => plain_text, :status => :unprocessable_entity }
    end
  end



  #############################################################################
  private # Misc Support methods
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

  # Returns the first CarminPathDataProvider that +user+
  # has access to. If the user has a prefered DP ID configured
  # and it happens to be a CarminPathDataProvider, then that's
  # the one returned.
  def find_default_carmin_provider_for_user(user, klass = CarminPathDataProvider)
    pref_id  = user.meta[:pref_data_provider_id] # in case it's a CarminPathDataProvider
    if pref_id.present?
      dp = klass.find_all_accessible_by_user(user).where(:id => pref_id).first
      return dp if dp
    end
    klass.find_all_accessible_by_user(user).first
  end

  # This method is used to find the storage userfile
  # associated with a CARMIN path.
  #
  # Given a path such as 'abcd/xyz/hello.txt', it will
  # search for and return the FileCollection 'abcd' belonging to +user+
  # on the current data provider, and return "xyz/hello.txt" as
  # a Pathname object. The FileCollection object might be
  # a new record, not yet saved.
  #
  # If the given path has only one component, the returned
  # object will be the first match in the database, or
  # a Userfile object which will also be a new record. Note
  # that in the latter case, objects of class Userfile cannot be
  # saved, so it's expected that the user of the method will
  # change the object to a proper subclass before saving it.
  def carmin_path_to_userfile_and_subpath(path, user, dp) #:nodoc:
    cb_error "CARMIN path is illegal: #{path}" if path.blank?
    path = Pathname.new(path)
    cb_error "CARMIN path is not relative: #{path}" unless path.relative?
    components     = path.each_filename.to_a
    userfile_name  = components.shift
    subpath        = Pathname.new("").join(*components)
    userfile_class = subpath.to_s.blank? ? Userfile : FileCollection # not SingleFile!
    userfile       = userfile_class.find_or_initialize_by(
                       :name             => userfile_name,
                       :user_id          => user.id,
                       :group_id         => user.own_group.id,
                       :data_provider_id => dp.id,
                     )
    return userfile, subpath
  end

  # Builds a path inside the file collection,
  # and makes sure all components already exists up to
  # (but NOT including) the last component.
  # Returns (for convenience) the full_path and the parent path.
  def check_filecollection_structure_exists(userfile, subpath) #:nodoc:
    full_path = userfile.cache_full_path + subpath
    parent    = full_path.parent
    carmin_error("Path doesn't exist: #{parent.basename}", Errno::ENOENT) if
      ! File.directory?(parent.to_s)
    return full_path, parent # useful
  end

  # The +userfile+ is usually a file collection;
  # +full_path+ can be any path it its cache, but it must exist.
  def extract_archive_in_collection(userfile, full_path, archive) #:nodoc:
    capt_outerr = "/tmp/capt.#{Process.pid}.#{rand(100000)}.outerr"
    userfile.cache_writehandle do
      IO.popen("cd #{full_path.to_s.bash_escape};tar -xzf - 1>#{capt_outerr} 2>&1","wb") do |fh|
        fh.write archive
      end
    end # sync_to_provider automatically called
    capt = File.read(capt_outerr)
    # TODO clean up ignorabled messages here maybe?
    return capt
  ensure
    File.unlink(capt_outerr) rescue nil
  end

end
