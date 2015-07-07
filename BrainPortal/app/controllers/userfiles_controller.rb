
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

require 'fileutils'

# RESTful controller for the Userfile resource.
class UserfilesController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  api_available

  before_filter :login_required
  before_filter :auto_add_persistent_userfile_ids, :except => [ :manage_persistent ]
  around_filter :permission_check, :only => [
      :download, :update_multiple, :delete_files, :create_collection, :change_provider, :quality_control,
      :manage_persistent
  ]

  MAX_DOWNLOAD_MEGABYTES = 400

  # GET /userfiles
  # GET /userfiles.xml
  def index #:nodoc:

    #------------------------------
    # Header scope
    #------------------------------

    @header_scope = header_scope(@filter_params)

    #------------------------------
    # Filtered scope
    #------------------------------

    @filtered_scope = filter_scope(@filter_params,@header_scope)

    #------------------------------
    # Sorted scope
    #------------------------------

    sorted_scope, joins = sorted_scope(@filter_params,@header_scope,@filtered_scope)

    #------------------------------
    # Tags
    #------------------------------

    tags_and_total_counts = @header_scope.select("tags.name as tag_name, tags.id as tag_id, COUNT(tags.name) as tag_count").joins(:tags).group("tags.name")
    filt_tag_counts       = @filtered_scope.joins(:tags).group("tags.name").count
    @tag_filters          = tags_and_total_counts.map { |tc| ["#{tc.tag_name} (#{filt_tag_counts[tc.tag_name].to_i}/#{tc.tag_count})", { :parameter  => :filter_tags_array, :value => tc.tag_id, :class => "#{"filter_zero" if filt_tag_counts[tc.tag_name].blank?}" }]  }

    #------------------------------
    # Pagination preparation
    #------------------------------

    # For Pagination
    unless [:html, :js].include?(request.format.to_sym)
      @per_page = 999_999_999
    end
    @current_offset = offset = (@current_page - 1) * @per_page


    #------------------------------
    # Final paginated array of objects
    #------------------------------

    includes = [ :user, :data_provider, :sync_status, :tags, :group ] # used only when fetching objects for rendering the page

    # ---- NO tree sort ----
    @filter_params["tree_sort"] = "on" if @filter_params["tree_sort"].blank?
    if @filter_params["tree_sort"] == "off" || ![:html, :js].include?(request.format.to_sym)
      @filtered_scope  = @filtered_scope.scoped( :joins => :user ) if current_user.has_role?(:site_manager)
      # use 'distinct userfiles.id' on count in order to remove duplicate entry
      # due to the presence of file with multiple status
      @userfiles_total      = @filtered_scope.count("distinct userfiles.id")
      ordered_real          = sorted_scope.includes(includes - joins).offset(offset).limit(@per_page).all
    # ---- WITH tree sort ----
    else
      # We first get a list of 'simple' objects [ id, parent_id ]
      simple_pairs      = sorted_scope.raw_rows( [ "userfiles.id", "userfiles.parent_id" ] )
      simple_pairs      = tree_sort_by_pairs(simple_pairs) # private method in this controller
      # At this point, each simple_pair is [ userfile_id, parent_id, [ child1_id, child2_id... ], orig_idx, level ]
      @userfiles_total  = simple_pairs.size
      if params[:find_file_id]
        find_file_id    = params[:find_file_id].to_i
        find_file_index = simple_pairs.index { |u| u[0] == find_file_id }
        if find_file_index
          @current_page = (find_file_index / @per_page) + 1
          offset = (@current_page - 1) * @per_page
        end
      end

      # Paginate the list of simple objects
      page_of_userfiles = simple_pairs[offset, @per_page] || []

      # Fetch the real objects and collect them in the same order
      userfile_ids      = page_of_userfiles.collect { |u| u[0] }
      real_subset       = @filtered_scope.includes( includes ).where( :id => userfile_ids )
      real_subset_index = real_subset.index_by { |u| u.id }
      ordered_real      = []

      page_of_userfiles.each do |simple|
        full = real_subset_index[simple[0].to_i]
        next unless full # this can happen when the userfile list change between fetching the simple and real lists
        full.level = simple[4]
        ordered_real << full
      end

    end

    @userfiles_total_size = @filtered_scope.sum(:size)



    #------------------------------
    # Real page of userfile objects
    #------------------------------

    # Turn the array ordered_real into the final paginated collection
    @userfiles = WillPaginate::Collection.create(@current_page, @per_page) do |pager|
      pager.replace(ordered_real || [])
      pager.total_entries = @userfiles_total
      pager
    end

    # Count the number of hidden files, only if the current view option is not showing them.
    # This code depends on AREL's 'where_values' method, which is not official ?
    @hidden_total = nil
    if @filter_params["view_hidden"] != 'on'
      @hidden_total  = @filtered_scope.undo_where(:hidden).where(:hidden => true).count
    end

    @archived_total  = @filtered_scope.where(:archived => true).count
    @immutable_total = @filtered_scope.where(:immutable => true).count

    current_session.save_preferences_for_user(current_user, :userfiles, :view_hidden, :tree_sort, :view_all, :details, :per_page)
    respond_to do |format|
      format.html
      format.js
      format.xml  { render :xml  => @userfiles.to_xml(:methods => :type) }
      format.json { render :json => @userfiles.to_json(:methods => :type) }
      format.csv
    end
  end

  def new_parent_child #:nodoc:

    file_ids     = params[:file_ids]
    @userfiles   = Userfile.find_all_accessible_by_user(current_user, :access_requested => :write).where(:id => file_ids).all
    @have_parent = @userfiles.any? { |u| u.parent_id  }
    if ! ( @userfiles.size >= 2  || @have_parent )
      render :text  => "<span class=\"warning\">You must select either:<br> 1) several files without parents or<br> 2) one file with a parent.</span>"
      return
    end

    render :action  => :new_parent_child, :layout  => false
  end

  def create_parent_child #:nodoc:
    parent_id = params[:parent_id]
    child_ids = params[:child_ids]

    if child_ids.blank?
      flash[:error] = "Must have at least one file selected for this operation."
    else
      child_ids.delete(parent_id)
      @children = Userfile.find_accessible_by_user(params[:child_ids], current_user)
      @parent   = parent_id.present? && Userfile.find_accessible_by_user(params[:parent_id], current_user)
      @parent ? @children.each { |c| c.move_to_child_of(@parent) }
              : @children.each { |c| c.remove_parent() }
    end

    redirect_to :action => :index
  end

  # Transfer contents of a file.
  # If no relevant parameters are given, the controller
  # will simply attempt to send the entire file.
  # Otherwise, it will modify it's response according
  # to the following parameters:
  # [:content_loader] a content loader defined for the
  #                   userfile.
  # [:arguments]      arguments to pass to the content
  #                   loader method.
  #
  # GET /userfiles/1/content?option1=....optionN=...
  def content
    @userfile = Userfile.find_accessible_by_user(params[:id], current_user, :access_requested => :read)

    content_loader = @userfile.find_content_loader(params[:content_loader])
    argument_list  = params[:arguments] || []
    argument_list  = [argument_list] unless argument_list.is_a?(Array)

    if content_loader
      response_content = @userfile.send(content_loader.method, *argument_list)
      if content_loader.type == :send_file
        send_file response_content
      elsif content_loader.type == :gzip
        response.headers["Content-Encoding"] = "gzip"
        render :text => response_content
      else
        render content_loader.type => response_content
      end
    else
      @userfile.sync_to_cache
      send_file @userfile.cache_full_path, :stream => true, :filename => @userfile.name
    end
  rescue
    respond_to do |format|
       format.html { render :file    => "public/404.html", :status => 404 }
       format.xml  { render :nothing => true,              :status => 404 }
       format.json { render :nothing => true,              :status => 404 }
    end
  end

  # Renders a partial within the 'show' page by invoking
  # some custom viewer code registered by a Userfile subclass.
  # The main parameter is :viewer ; an optional :viewer_userfile_class
  # can be provided to override which class to search for the viewer code
  # (by default, the class of +userfile+)
  def display
    @userfile = Userfile.find_accessible_by_user(params[:id], current_user, :access_requested => :read)

    viewer_name           = params[:viewer]
    viewer_userfile_class = params[:viewer_userfile_class].presence.try(:constantize) || @userfile.class

    # Try to find out viewer aming those registered in the classes
    @viewer      = viewer_userfile_class.find_viewer(viewer_name)
    @viewer    ||= (viewer_name.camelcase.constantize rescue nil).try(:find_viewer, viewer_name) rescue nil

    # If no viewer object is found but the argument "viewer_name" correspond to a partial
    # on disk, then let's create a transient viewer object representing that file.
    # Not an officially registered viewer, but it will work for the current rendering.
    if @viewer.blank? && viewer_name =~ /^\w+$/
      partial_filename_base = (viewer_userfile_class.view_path + "_#{viewer_name}.#{request.format.to_sym}").to_s
      if File.exists?(partial_filename_base) || File.exists?(partial_filename_base + ".erb")
        @viewer = Userfile::Viewer.new(viewer_userfile_class, :partial => viewer_name)
      end
    end

    # Ok, some viewers are invalid for some specific userfiles, so reject it if it's the case.
    @viewer      = nil if @viewer && ! @viewer.valid_for?(@userfile)

    begin
      if @viewer
        if params[:apply_div] == "false"
          render :file   => @viewer.partial_path.to_s, :layout => false
        else
          render :action => :display,                  :layout => false
        end
      else
        render :text => "<div class=\"warning\">Could not find viewer #{viewer_name}.</div>", :status  => "404"
      end
    rescue ActionView::Template::Error => e
      exception = e.original_exception

      raise exception unless Rails.env == 'production'
      ExceptionLog.log_exception(exception, current_user, request)
      Message.send_message(current_user,
        :message_type => 'error',
        :header => "Could not view #{@userfile.name}",
        :description => "An internal error occured when trying to display the contents of #{@userfile.name}."
      )

      render :text => "<div class=\"warning\">Error generating view code for viewer #{params[:viewer]}.</div>", :status => "500"
    end
  end

  def show #:nodoc:
    @userfile = Userfile.find_accessible_by_user(params[:id], current_user, :access_requested => :read)

    # This allows the user to manually trigger the syncing to the Portal's cache
    @sync_status        = 'ProvNewer' # same terminology as in SyncStatus
    state               = @userfile.local_sync_status
    @sync_status        = state.status if state
    @viewer             = @userfile.viewers.first

    @log                = @userfile.getlog        rescue nil

    # Add some information for json
    if request.format =~ "json"
      rr_ids_accessible   = RemoteResource.find_all_accessible_by_user(current_user).map(&:id)
      @remote_sync_status = SyncStatus.where(:userfile_id => @userfile.id, :remote_resource_id => rr_ids_accessible)
      @children_ids       = @userfile.children_ids  rescue []

      @userfile[:log]                = @log
      @userfile[:remote_sync_status] = @remote_sync_status
      @userfile[:children_ids]       = @children_ids
    # Prepare next/previous userfiles for html
    elsif request.format.to_sym == :html
      @sort_index     = params[:sort_index].to_i || 0

      # Rebuild the sorted Userfile scope
      @filter_params  = current_session.params_for(params[:proxy_destination_controller] || params[:controller])
      header_scope    = header_scope(@filter_params)
      filtered_scope  = filter_scope(@filter_params, header_scope)
      sorted_scope, _ = sorted_scope(@filter_params, header_scope, filtered_scope)

      # Fetch the neighbors of the shown userfile in the ordered scope's order
      neighbors = sorted_scope.where("userfiles.id != ?", @userfile.id).offset([0, @sort_index - 1].max).limit(2).all
      neighbors.unshift nil if @sort_index == 0

      @previous_userfile, @next_userfile = neighbors
    end

    respond_to do |format|
      format.html
      format.xml  { render :xml  => @userfile }
      format.json { render :json => @userfile }
    end
  end

  def new #:nodoc:
    @user_tags      = current_user.available_tags
    @data_providers = DataProvider.find_all_accessible_by_user(current_user).all
    @data_providers.reject! { |dp| dp.meta[:no_uploads].present? }
  end

  # Triggers the mass synchronization of several userfiles
  # or mass 'desynchronization' (ProvNewer) of several userfiles.
  def sync_multiple #:nodoc:

    operation = params[:operation] || "sync_local"  # that, or "all_newer"

    @userfiles = Userfile.find_accessible_by_user(params[:file_ids], current_user, :access_requested => :read)

    # Mark files as newer on provider side
    if operation == "all_newer" # simpler case
      updated = 0
      SyncStatus.where(:userfile_id => @userfiles.map(&:id), :status => [ "InSync" ]).all.each do |ss|
        updated += 1 if ss.status_transition(ss.status,"ProvNewer")
      end
      flash[:notice] = "Marked #{updated} files as newer on their Data Provider."
      redirect_to :action  => :index
      return
    end

    # Sync files to the portal's cache
    CBRAIN.spawn_with_active_records(current_user, "Synchronization of #{@userfiles.size} files.") do
      @userfiles.each do |userfile|
        state = userfile.local_sync_status
        sync_status = 'ProvNewer'
        sync_status = state.status if state

        if sync_status !~ /^To|InSync|Corrupted/
          if (userfile.sync_to_cache rescue nil)
            userfile.set_size
          end
        end
      end
    end # spawn

    flash[:notice] = "Synchronization started in background. Files that cannot be synchronized will be skipped."

    if @userfiles.size == 1 && params[:back_to_show_page]
      redirect_to :controller => :userfiles, :action  => :show, :id => @userfiles[0].id
    else
      redirect_to :action  => :index
    end
  end

  # POST /userfiles
  # POST /userfiles.xml

  #The create action is used to save uploaded files to a DataProvider.
  #
  #Generally, the file is simply saved to the DataProvider as is.
  #There are, however, special options for archive files (.tar, .tar.gz, or .zip).
  #Given the value of the +archive+ parameter, the user may perform one
  #of the following on the uploaded archive.
  #[*save*] Save the archive to the DataProvider as is.
  #[*collection*] Extract the files from the archive into a FileCollection.
  #[*extract*] Extract the files in the archive and individually register
  #            them as Userfile entries. This option is limited in that
  #            a maximum of 50 files may be extracted in this way, and
  #            no files nested within directories will be extracted
  #            (the +collection+ option has no such limitations).
  def create #:nodoc:
    
    flash[:error]     ||= ""
    flash[:notice]    ||= ""
    params[:userfile] ||= {}

    redirect_path = params[:redirect_to] || {:action  => :index}

    # Get the upload stream object
    upload_stream = params[:upload_file]   # an object encoding the file data stream
    if upload_stream.blank?
      respond_to do |format|
        format.html  { redirect_to redirect_path }
        format.json  { head :unprocessable_entity }
      end
      return
    end

    # Save raw content of the file; we don't know yet
    # whether it's an archive or not, or if we'll extract it etc.
    basename    = File.basename(upload_stream.original_filename)

    # Identify the file type
    file_type   = params[:file_type].presence.try(:constantize) rescue nil
    file_type ||= Userfile.suggested_file_type(basename) || SingleFile
    file_type   = SingleFile unless file_type < Userfile

    # Temp file where the data is saved by rack
    rack_tempfile_path = upload_stream.tempfile.path
    rack_tempfile_size = upload_stream.tempfile.size

    # Get the data provider for the destination files.
    data_provider_id   = params[:data_provider_id]

    # Where we'll keep a copy in the spawn() below
    tmpcontentfile     = "/tmp/#{Process.pid}-#{rand(10000).to_s}-#{basename}" # basename's extension is used later on

    # Decide what to do with the raw data
    if params[:archive] == 'save'  # the simplest case first

      file_type = SingleFile unless file_type <= SingleFile
      userfile  = file_type.new(
                      params[:userfile].merge(
                     :name             => basename,
                     :user_id          => current_user.id,
                     :data_provider_id => data_provider_id,
                     :tag_ids          => params[:tags]
                   )
                 )
      
      if !userfile.save
        flash[:error]  += "File '#{basename}' could not be added.\n"
        userfile.errors.each do |field, error|
          flash[:error] += "#{field.to_s.capitalize} #{error}.\n"
        end
        respond_to do |format|
          format.json { render :json  => flash[:error], :status  => :unprocessable_entity}
        end
        return
      end

      flash[:notice] += "File '#{basename}' being added in background."

      system("cp #{rack_tempfile_path.to_s.bash_escape} #{tmpcontentfile.to_s.bash_escape}") # fast, hopefully; maybe 'mv' would work?
      CBRAIN.spawn_with_active_records(current_user,"Upload of SingleFile") do
        begin
          userfile.cache_copy_from_local_file(tmpcontentfile)
          userfile.size = rack_tempfile_size
          userfile.save
          userfile.addlog_context(self, "Uploaded by #{current_user.login}")
          Message.send_message(current_user,
                               :message_type   => 'notice',
                               :header         => "File Uploaded",
                               :variable_text  => "#{userfile.pretty_type} [[#{userfile.name}][/userfiles/#{userfile.id}]]"
                               )
        ensure
          File.delete(tmpcontentfile) rescue true
        end
      end # spawn

      respond_to do |format|
        format.html { redirect_to redirect_path }
        format.json { render :json => {:notice => "File Uploaded"} }
      end
      return
    end # save

    # We will be processing some archive file.
    # First, check for supported extensions
    if basename !~ /(\.tar|\.tgz|\.tar.gz|\.zip)$/i
      flash[:error] += "Error: file #{basename} does not have one of the supported extensions: .tar, .tar.gz, .tgz or .zip.\n"
      respond_to do |format|
        format.html { redirect_to redirect_path }
        format.json { render :json  => flash[:error], :status  => :unprocessable_entity}
      end
      return
    end

    # Create a collection
    if params[:archive] =~ /collection/

      collection_name = basename.split('.')[0]  # "abc"
      if current_user.userfiles.exists?(:name => collection_name, :data_provider_id => data_provider_id)
        flash[:error] = "Collection '#{collection_name}' already exists.\n"
        respond_to do |format|
          format.html { redirect_to redirect_path }
          format.json { render :json  => flash[:error], :status  => :unprocessable_entity}
        end
        return
      end

      collectionType = file_type
      collectionType = FileCollection unless file_type <= FileCollection

      collection = collectionType.new(
        params[:userfile].merge(
          :name              => collection_name,
          :user_id           => current_user.id,
          :data_provider_id  => data_provider_id,
          :tag_ids           => params[:tags]
        )
      )

      if collection.save
        system("cp #{rack_tempfile_path.to_s.bash_escape} #{tmpcontentfile.to_s.bash_escape}") # fast, hopefully; maybe 'mv' would work?
        CBRAIN.spawn_with_active_records(current_user, "FileCollection Extraction") do
          begin
            collection.extract_collection_from_archive_file(tmpcontentfile)
            Message.send_message(current_user,
                                  :message_type   => 'notice',
                                  :header         => "Collection Uploaded",
                                  :variable_text  => "#{collection.pretty_type} [[#{collection.name}][/userfiles/#{collection.id}]]"
                                  )
          ensure
            File.delete(tmpcontentfile) rescue true
          end
        end # spawn

        flash[:notice] = "Collection '#{collection_name}' created."
        current_user.addlog_context(self,"Uploaded #{collection.class} '#{collection_name}'")
        respond_to do |format|
          format.html { redirect_to redirect_path }
          format.json { render :json => {:notice => "Collection Uploaded" } }
        end
      else
        flash[:error] = "Collection '#{collection_name}' could not be created.\n"
        collection.errors.each do |field, error|
          flash[:error] += field.to_s.capitalize + " " + error + ".\n"
        end
        respond_to do |format|
          format.html { redirect_to redirect_path }
          format.json { render :json  => flash[:error], :status  => :unprocessable_entity}
        end
      end # save collection
      return
    end

    # At this point, create a bunch of userfiles from the archive
    cb_error "Unknown action #{params[:archive]}" if params[:archive] != 'extract'

    # Common attributes to all files
    attributes = params[:userfile].merge({
      :user_id           => current_user.id,
      :data_provider_id  => data_provider_id,
      :tag_ids           => params[:tags]
    })

    # Do it in background.
    system("cp #{rack_tempfile_path.to_s.bash_escape} #{tmpcontentfile.to_s.bash_escape}") # fast, hopefully; maybe 'mv' would work?
    CBRAIN.spawn_with_active_records(current_user,"Archive extraction") do
      begin
        extract_from_archive(tmpcontentfile, params[:file_type].presence, attributes) # generates its own Messages
      ensure
        File.delete(tmpcontentfile) rescue true
      end
    end # spawn

    flash[:notice] += "Your files are being extracted and added in background."
    respond_to do |format|
      format.html { redirect_to redirect_path }
      format.json { render :json => {:notice => "Archive Uploaded" } }
    end
  end

  # PUT /userfiles/1
  # PUT /userfiles/1.xml
  def update  #:nodoc:
    @userfile = Userfile.find_accessible_by_user(params[:id], current_user, :access_requested => :write)

    flash[:notice] = ""
    flash[:error]  = ""

    if @userfile.has_owner_access?(current_user)
      attributes    = params[:userfile] || {}
      new_user_id   = attributes.delete :user_id
      new_group_id  = attributes.delete :group_id
      type          = attributes.delete :type

      old_name = @userfile.name
      new_name = attributes.delete(:name) || old_name

      @userfile.attributes = attributes
      @userfile.type       = type         if type
      @userfile.user_id    = new_user_id  if current_user.available_users.where(:id => new_user_id).first
      @userfile.group_id   = new_group_id if current_user.available_groups.where(:id => new_group_id).first
      @userfile            = @userfile.class_update

      if @userfile.save_with_logging(current_user, %w( group_writable num_files parent_id hidden ) )
        if new_name != old_name
          @userfile.provider_rename(new_name)
          @userfile.addlog("Renamed by #{current_user.login}: #{old_name} -> #{new_name}")
        end
      end
    end

    @userfile.set_tags_for_user(current_user, params[:tag_ids])
    respond_to do |format|
      if @userfile.errors.empty?
        flash[:notice] += "#{@userfile.name} successfully updated."
        format.html { redirect_to(:action  => 'show') }
        format.xml  { head :ok }
      else
        @userfile.reload
        format.html { render(:action  => 'show') }
        format.xml  { render :xml => @userfile.errors, :status => :unprocessable_entity }
      end
    end
  end

  # Updated tags, groups or group-writability flags for several
  # userfiles.
  def update_multiple #:nodoc:
    file_ids        = params[:file_ids]
    commit_name     = extract_params_key([ :update_tags, :update_projects, :update_permissions, :update_owner, :update_file_type, :update_hidden , :update_immutable], "")
    commit_humanize = commit_name.to_s.humanize

    # First selection no need to be in spawn
    invalid_tags     = 0
    unable_to_update = nil
    operation        =
      case commit_name
        when :update_tags
          new_tags         = params[:tags] || []
          new_tags.reject! { |tag| !current_user.available_tags.where(:id => tag.to_i).exists? && invalid_tags += 1 }
          ['set_tags_for_user', current_user, new_tags]
        when :update_projects
          new_group_id     = params[:userfile][:group_id].to_i
          unable_to_update = "project" if !current_user.available_groups.where(:id => new_group_id).exists?
          ["update_attributes_with_logging", {:group_id => new_group_id}, current_user]
        when :update_permissions
          ["update_attributes_with_logging", {:group_writable => params[:userfile][:group_writable]}, current_user, [ 'group_writable' ] ]
        when :update_owner
          new_user_id      = params[:userfile][:user_id].to_i
          unable_to_update = "owner"   if !current_user.available_users.where(:id => new_user_id).exists?
          ["update_attributes_with_logging", {:user_id => new_user_id}, current_user]
        when :update_file_type
          ["update_file_type", params[:file_type], current_user]
        when :update_hidden
          ["update_attributes_with_logging", {:hidden => params[:userfile][:hidden]}, current_user, [ 'hidden' ] ]
        when :update_immutable
          ["update_attributes_with_logging", {:immutable => params[:userfile][:immutable]}, current_user, [ 'immutable' ] ]
        else
          nil
      end # case statement

    if unable_to_update.present? || operation.blank?
      flash[:error]   = "You do not have access to this #{unable_to_update}." if unable_to_update.present?
      flash[:error]   = "Unknown operation requested for updating the files." if operation.blank?
      redirect_action = params[:redirect_action] || {:action => :index, :format => request.format.to_sym}
      redirect_to redirect_action
      return
    end

    flash[:error] = "You do not have access to all tags you want to update." unless invalid_tags == 0
    do_in_spawn   = file_ids.size > 5
    success_list  = []
    failed_list   = {}
    CBRAIN.spawn_with_active_records_if(do_in_spawn,current_user,"Sending update to files") do
      access_requested = commit_name == :update_tags ? :read : :write
      filelist         = Userfile.find_all_accessible_by_user(current_user, :access_requested => access_requested ).where(:id => file_ids).all
      failure_ids      = file_ids - filelist.map {|u| u.id.to_s }
      failed_files     = Userfile.where(:id => failure_ids).select([:id, :name, :type]).all
      failed_list["you don't have write access"] = failed_files if failed_files.present?

      # Filter file list
      case commit_name
        # Critical! Case values must match labels of submit buttons!
        when :update_projects
          user_to_avail_group_ids = {}
          new_filelist            = filelist
          new_filelist.reject! do |file|
            f_uid = file.user_id
            # File's owner need to have access to new group
            user_to_avail_group_ids[f_uid] ||= User.find(f_uid).available_groups.map(&:id).index_by { |id| id }
            (! user_to_avail_group_ids[f_uid][new_group_id])
          end
          failed_files = filelist - new_filelist
          failed_list["new group is not accessible by file's owner"] = failed_files if failed_files.present?
          filelist     = new_filelist
        when :update_owner
          new_filelist = filelist.select(&:allow_file_owner_change?)
          failed_files = filelist - new_filelist
          failed_list["you are not allowed to change file owner on this data provider"] = failed_files if failed_files.present?
          filelist     = new_filelist
      end
      # Update the attribute for each file
      filelist.each do |userfile|
        if userfile.send(*operation)
          success_list << userfile
        else
          (failed_list["cannot update attribute"] ||= []) << userfile
        end
      end
      # Async Notification
      if do_in_spawn
        # Message for successful actions
        if success_list.present?
          notice_message_sender("#{commit_humanize} successful for your file(s)", success_list)
        end
        # Message for failed actions
        if failed_list.present?
          error_message_sender("#{commit_humanize} failed for your file(s)", failed_list)
        end
      end

    end # spawn end

    # Sync notification
    if do_in_spawn
      flash[:notice] = "The files are being updated in background."
    else
      flash[:notice] = "#{commit_humanize} successful for #{view_pluralize(success_list.count, "file")}."   if success_list.present?
      failure_count  = 0
      failed_list.each_value { |v| failure_count += v.size }
      flash[:error]  = "#{commit_humanize} unsuccessful for #{view_pluralize(failure_count, "file")}." if failure_count > 0
    end

    redirect_action  = params[:redirect_action] || {:action => :index, :format => request.format.to_sym}
    redirect_to redirect_action
  end

  def quality_control #:nodoc:
    @filelist = params[:file_ids] || []
  end

  def quality_control_panel #:nodoc:
    @filelist      = params[:file_ids] || []
    @current_index = params[:index]    || -1

    @current_index = @current_index.to_i

    admin_user     = User.find_by_login("admin")
    everyone_group = Group.everyone

    pass_tag    = current_user.available_tags.find_or_create_by_name_and_user_id_and_group_id("QC_PASS", admin_user.id, everyone_group.id)
    fail_tag    = current_user.available_tags.find_or_create_by_name_and_user_id_and_group_id("QC_FAIL", admin_user.id, everyone_group.id)
    unknown_tag = current_user.available_tags.find_or_create_by_name_and_user_id_and_group_id("QC_UNKNOWN", admin_user.id, everyone_group.id)

    commit_name     = extract_params_key([ :next, :previous, :pass, :fail, :unknown ])
    if @current_index >=  0 && commit_name && commit_name != :next && commit_name != :previous
      @current_userfile = Userfile.find_accessible_by_user(@filelist[@current_index], current_user, :access_requested => :read)
      tag_ids = params[:tag_ids] || []
      case commit_name
      when :pass
        tag_ids |= [pass_tag.id.to_s]
      when :fail
        tag_ids |= [fail_tag.id.to_s]
      when :unknown
        tag_ids |= [unknown_tag.id.to_s]
      end
      @current_userfile.set_tags_for_user(current_user, tag_ids)
    end

    if commit_name == :previous && @current_index > 0
      @current_index -= 1
    elsif @current_index < @filelist.size-1
      @current_index += 1
    end

    @userfile     = Userfile.find_accessible_by_user(@filelist[@current_index], current_user, :access_requested => :read)
    @qc_view_file = @userfile.view_path("qc_panel.html.erb").to_s # model-specific view partial, in its plugin directory
    if ! File.exists?(@qc_view_file)
      @qc_view_file = "userfiles/_default_qc_panel.html.erb" # default provided by cbrain
    end

    render :partial => "quality_control_panel"
  end

  #Create a collection from the selected files.
  def create_collection #:nodoc:
    filelist         = params[:file_ids]
    data_provider_id = params[:data_provider_id_for_collection]
    collection_name  = params[:collection_name]
    file_group       = current_project ? current_project.id : current_user.own_group.id

    if data_provider_id.blank?
      flash[:error] = "No data provider selected.\n"
      redirect_to :action => :index, :format => request.format.to_sym
      return
    end

    # Handle collection name
    if collection_name.blank?
      suffix = Time.now.to_i
      while Userfile.where(:user_id => current_user.id, :name => "Collection-#{suffix}").first.present?
        suffix += 1
      end
      collection_name = "Collection-#{suffix}"
    end

    if ! Userfile.is_legal_filename?(collection_name)
      flash[:error] = "Error: collection name '#{collection_name}' is not acceptable (illegal characters?)."
      redirect_to :action => :index, :format =>  request.format.to_sym
      return
    end

    # Check if the collection name chosen by the user already exists for this user on the data_provider
    if current_user.userfiles.exists?(:name => collection_name, :data_provider_id => data_provider_id)
      flash[:error] = "Error: collection with name '#{collection_name}' already exists."
      redirect_to :action => :index, :format =>  request.format.to_sym
      return
    end

    if Userfile.find_accessible_by_user(filelist, current_user, :access_requested  => :read).count == 0
      flash[:error] = "Error: No accessible files selected."
      redirect_to :action => :index, :format =>  request.format.to_sym
      return
    end

    collection = FileCollection.new(
      :user_id          => current_user.id,
      :group_id         => file_group,
      :data_provider_id => data_provider_id,
      :name             => collection_name
    )

    CBRAIN.spawn_with_active_records(current_user,"Collection Merge") do
      begin
        userfiles = Userfile.find_accessible_by_user(filelist, current_user, :access_requested  => :read)
        result    = collection.merge_collections(userfiles)
        if result == :success
          Message.send_message(current_user,
                              :message_type  => :notice,
                              :header        => "Collections Merged",
                              :variable_text => "[[#{collection.name}][/userfiles/#{collection.id}]]"
                              )
        elsif result == :collision
          Message.send_message(current_user,
                              :message_type  => :error,
                              :header        => "Collection could not be merged.",
                              :variable_text => "There was a collision among the file names."
                              )
        end
      rescue => e
        Message.send_message(current_user,
                            :message_type  => :error,
                            :header        => "The collection was not created correctly on #{DataProvider.find_all_accessible_by_user(current_user).where( :id => data_provider_id, :online => true, :read_only => false ).first.name}",
                            :variable_text => "#{e.message}\n#{collection.name}\n"
                              )
      end
    end # spawn

    flash[:notice] = "Collection #{collection.name} is being created in background."
    redirect_to :action => :index, :format => request.format.to_sym

  end

  # Copy or move files to a new provider.
  def change_provider #:nodoc:

    # Destination provider
    data_provider_id = params[:data_provider_id_for_mv_cp]
    if data_provider_id.blank?
      flash[:error] = "No data provider selected.\n"
      redirect_to :action => :index, :format => request.format.to_sym
      return
    end

    # Option for move or copy.
    crush_destination = (params[:crush_destination].to_s =~ /crush/i) ? true : false

    # File list to apply operation
    filelist    = params[:file_ids] || []

    # Operaton to perform
    task       = extract_params_key([ :move, :copy ], "")
    word_move  = task == :move ? 'move'  : 'copy'
    word_moved = task == :move ? 'moved' : 'copied'

    new_provider    = DataProvider.find_all_accessible_by_user(current_user).where( :id => data_provider_id, :online => true, :read_only => false ).first
    unless new_provider
      flash[:error] = "Data provider #{data_provider_id} not accessible.\n"
      respond_to do |format|
        format.html { redirect_to :action => :index }
        format.json { render :json => { :error => flash[:error]}, :status => :forbidden }
      end
      return
    end

    # Spawn subprocess to perform the move operations
    success_list  = []
    failed_list   = {}
    CBRAIN.spawn_with_active_records_if(request.format.to_sym != :json, current_user, "#{word_move.capitalize} To Other Data Provider") do
      filelist.each_with_index do |id,count|
        $0 = "#{word_move.capitalize} ID=#{id} #{count+1}/#{filelist.size} To #{new_provider.name}\0"
        begin
          u = Userfile.find_accessible_by_user(id, current_user, :access_requested => (task == :copy ? :read : :write) )
          next unless u
          orig_provider = u.data_provider
          next if orig_provider.id == data_provider_id # no support for copy to same provider in the interface, yet.
          res = nil
          if task == :move
            raise "not owner" unless u.has_owner_access?(current_user)
            res = u.provider_move_to_otherprovider(new_provider, :crush_destination => crush_destination)
          else
            my_group_id  = current_project ? current_project.id : current_user.own_group.id
            res = u.provider_copy_to_otherprovider(new_provider,
                     :user_id           => current_user.id,
                     :group_id          => my_group_id,
                     :crush_destination => crush_destination
                  )
          end
          raise "file collision: there is already such a file on the other provider" unless res
          u.cache_erase rescue nil
          success_list << u
        rescue => e
          if u.is_a?(Userfile)
            (failed_list[e.message] ||= []) << u
          else
            raise e
          end
        end
      end

      if success_list.present?
        notice_message_sender("Files #{word_moved} to #{new_provider.name}",success_list)
      end
      if failed_list.present?
        error_message_sender("Some files could not be #{word_moved} to #{new_provider.name}",failed_list)
      end
    end # spawn

    flash[:notice] = "Your files are being #{word_moved} in the background.\n"

    respond_to do |format|
        format.html { redirect_to :action => :index }
        format.json { render :json => { :success_list => success_list.map(&:id), :failed_list => failed_list.map(&:id) } }
    end
  end

  # Adds the selected userfile IDs to the session's persistent list
  def manage_persistent

    if (params[:operation] || 'clear') =~ /(clear|add|remove|replace)/i
      filelist  = params[:file_ids] || []
      operation = Regexp.last_match[1].downcase
    elsif (params[:operation]) =~ /select/i
      operation      = "add"
      # Reduce userfiles list according to @filter_params
      filelist       = []
      header_scope   = header_scope(@filter_params)
      filtered_scope = filter_scope(@filter_params, header_scope)
      filtered_scope.each do |f|
        filelist << f.id.to_s if f.available?
      end
    else
      operation = 'clear'
    end

    flash[:notice] = ""

    cleared_count = added_count = removed_count = 0

    if operation == 'clear' || operation == 'replace'
      cleared_count = current_session.persistent_userfile_ids_clear
      flash[:notice] += "#{view_pluralize(cleared_count, "file")} cleared from persistent list.\n" if cleared_count > 0
    end

    if operation == 'add'   || operation == 'replace'
      added_count   = current_session.persistent_userfile_ids_add(filelist)
      flash[:notice] += "#{view_pluralize(added_count, "file")} added to persistent list.\n" if added_count > 0
    end

    if operation == 'remove'
      removed_count = current_session.persistent_userfile_ids_remove(filelist)
      flash[:notice] += "#{view_pluralize(removed_count, "file")} removed from persistent list.\n" if removed_count > 0
    end

    persistent_ids = current_session.persistent_userfile_ids_list
    flash[:notice] += "Total of #{view_pluralize(persistent_ids.size, "file")} now in the persistent list of files.\n" if
      persistent_ids.size > 0 && (added_count > 0 || removed_count > 0 || cleared_count > 0)

    flash[:notice] += "No changes made to the persistent list of userfiles." if
      added_count == 0 && removed_count == 0 && cleared_count == 0

    redirect_to :action => :index, :page => params[:page]
  end

  #Delete the selected files.
  def delete_files #:nodoc:
    filelist    = params[:file_ids] || []

    # Select all accessible files with write acces by the user.
    to_delete = Userfile.accessible_for_user(current_user, :access_requested => :write).where(:id => filelist)
    not_accessible_count = filelist.size - to_delete.size

    flash[:error] = "You do not have access to #{not_accessible_count} of #{filelist.size} file(s)." if not_accessible_count > 0

    # Delete in background
    deleted_success_list      = []
    unregistered_success_list = []
    failed_list               = {}
    CBRAIN.spawn_with_active_records_if(request.format.to_sym != :json, current_user, "Delete files") do
      to_delete.each_with_index do |userfile,count|
        $0 = "Delete ID=#{userfile.id} #{count+1}/#{to_delete.size}\0"
        begin
          userfile.destroy
          deleted_success_list << userfile
        rescue => e
          (failed_list[e.message] ||= []) << userfile
        end
      end

      if deleted_success_list.present?
        notice_message_sender("Finished deleting file(s)",deleted_success_list)
      end
      if unregistered_success_list.present?
        notice_message_sender("Finished unregistering file(s)",unregistered_success_list)
      end
      if failed_list.present?
        error_message_sender("Error when deleting/unregistering file(s)",failed_list)
      end
    end # spawn

    flash[:notice] = "Your files are being deleted in background."

    if request.format.to_sym == :json
      json_failed_list = {}
      failed_list.each do |error_message, userfiles|
        json_failed_list[error_message] = userfiles.map(&:id)
      end
    end

    respond_to do |format|
      format.html { redirect_to :action => :index }
      format.json { render :json => { :unregistered_list => unregistered_success_list.map(&:id),
                                      :deleted_list      => deleted_success_list.map(&:id),
                                      :failed_list       => json_failed_list,
                                      :error             => flash[:error]
                                    }
                  }
    end
  end


  # Dowload the selected files.
  def download #:nodoc:
    filelist           = params[:file_ids] || []
    specified_filename = params[:specified_filename]

    # Check or build filename for downloaded data
    # Does NOT include .tar.gz extensions, which will be added later if necessary
    if ! specified_filename.blank?
      specified_filename.sub!(/(\.tar)?(\.g?z)?$/i,"")
      if ! Userfile.is_legal_filename?(specified_filename)
          flash[:error] = "Error: filename '#{specified_filename}' is not acceptable (illegal characters?)."
          respond_to do |format|
            format.html { redirect_to :action => :index, :format =>  request.format.to_sym }
            format.json { render :json => { :error => flash[:error] } }
          end
          return
      end
    else
      is_blank  = true
      timestamp = Time.now.to_i.to_s[-4..-1]  # four digits long
      specified_filename = "cbrain_files_#{current_user.login}.#{timestamp}"
    end

    tot_size = 0

    # Find list of files accessible to the user
    userfiles_list = Userfile.find_accessible_by_user(filelist, current_user, :access_requested => :read)
    tot_size = userfiles_list.inject(0) { |total, u| total + (u.size || 0) }

    # Check size limit
    if tot_size > MAX_DOWNLOAD_MEGABYTES.megabytes
      flash[:error] = "You cannot download data that exceeds #{MAX_DOWNLOAD_MEGABYTES} megabytes using a browser.\n" +
                      "Consider using an externally accessible Data Provider (ask the admins for more info).\n"
      respond_to do |format|
          format.html { redirect_to :action => :index, :format =>  request.format.to_sym }
          format.json { render :json => { :error => flash[:error] } }
      end
      return
    end

    # Sync all files
    failed_list = {}
    userfiles_list.each do |userfile|
      begin
        userfile.sync_to_cache
      rescue => e
        (failed_list[e.message] ||= []) << userfile
      end
    end
    if failed_list.present?
      error_message_sender("Error when syncing file(s)", failed_list);
      respond_to do |format|
          format.html { redirect_to :action => :index, :format =>  request.format.to_sym }
          format.json { render :json => { :error => flash[:error] } }
      end
      return
    end

    # When sending a single file, just throw it at the browser.
    if userfiles_list.size == 1 && userfiles_list[0].is_a?(SingleFile)
      userfile = userfiles_list[0]
      fullpath = userfile.cache_full_path
      send_file fullpath, :stream => true, :filename => is_blank ? fullpath.basename : specified_filename
      return
    end

    # When several files are to be sent, create and send a .tar.gz file
    tarfile      = create_relocatable_tar_for_userfiles(userfiles_list,current_user.login)
    tarfile_name = "#{specified_filename}.tar.gz"
    send_file tarfile, :stream  => true, :filename => tarfile_name
    CBRAIN.spawn_fully_independent("DL clean #{current_user.login}") do
      sleep 3000
      File.unlink(tarfile)
    end
  end

  #Extract a file from a collection and register it separately
  #in the database.
  def extract_from_collection #:nodoc:
    success = failure = 0

    unless params[:file_names] && params[:file_names].size > 0
      flash[:notice] = "No files selected for extraction"
      redirect_to :action  => :show
      return
    end

    collection       = FileCollection.find_accessible_by_user(params[:id], current_user, :access_requested  => :read)
    collection_path  = collection.cache_full_path
    data_provider_id = collection.data_provider_id
    params[:file_names].each do |file|
      userfile = SingleFile.new(
          :name             => File.basename(file),
          :user_id          => current_user.id,
          :group_id         => collection.group_id,
          :data_provider_id => data_provider_id
      )
      Dir.chdir(collection_path.parent) do
        if userfile.save
          userfile.addlog("Extracted from collection '#{collection.name}'.")
          userfile.cache_copy_from_local_file(file)
          success += 1
        else
          failure += 1
        end
      end
      if success > 0
        flash[:notice] = "#{success} files were successfuly extracted."
      end
      if failure > 0
        flash[:error] =  "#{failure} files could not be extracted."
      end
    end

    redirect_to :action  => :index
  end

  # Compress or uncompress a set of userfiles; only supported
  # for SingleFiles.
  def compress  #:nodoc:
    filelist    = params[:file_ids] || []

    to_compress        = []
    to_uncompress      = []
    skipped_messages   = {}

    # First do basic verification on Userfile and split into 2 categories (compress/uncompress)
    Userfile.find_accessible_by_user(filelist, current_user, :access_requested => :write).each do |userfile|

      # Basic verification
      unless userfile.is_a?(SingleFile)
        (skipped_messages["Not a SingleFile"] ||= []) << userfile
        next
      end
      if userfile.data_provider.read_only?
        (skipped_messages["Data Provider not writable"] ||= []) << userfile
        next
      end

      # Check for collision
      basename = userfile.name
      destbase = basename =~ /\.gz$/i ? basename.sub(/\.gz$/i,"") : basename + ".gz"
      if Userfile.where(
           :name             => destbase,
           :user_id          => userfile.user_id,
           :data_provider_id => userfile.data_provider_id
         ).exists?
        (skipped_messages["Filename collision"] ||= []) << userfile
        next
      end

      # Split in 2 categories
      if basename =~ /\.gz$/i
        to_uncompress << [ userfile, :uncompress, destbase ]
      else
        to_compress   << [ userfile, :compress,   destbase ]
      end

    end

    # Skipped file notification
    if skipped_messages.present?
      flash[:error] = skipped_messages.map { |mes,list| "#{list.size} file collections skipped: #{mes}\n" }.join("")
    end

    if to_compress.size > 0 || to_uncompress.size > 0
      CBRAIN.spawn_with_active_records(current_user, "Compression") do
        success_list = []
        failed_list  = {}
        (to_compress + to_uncompress).each do |u_triplet|
          userfile,do_what,destbase = *u_triplet
          begin
            if ! userfile.provider_rename(destbase)
            (failed_list["could not do basic renaming"] ||= []) << userfile
              next
            end
            userfile.sync_to_cache
            SyncStatus.ready_to_modify_cache(userfile) do
              full_after = userfile.cache_full_path.to_s
              full_tmp   = "#{full_after}+#{$$}+#{Time.now.to_i}"
              command = (do_what == :compress) ? "gzip" : "gunzip"
              system("#{command} -c < #{full_after.bash_escape} > #{full_tmp.bash_escape}")
              File.rename(full_tmp,full_after) # crush it
            end
            userfile.sync_to_provider
            success_list << userfile
          rescue => e
            (failed_list[e.message] ||= []) << userfile
          end
        end

        if success_list.present?
          notice_message_sender("Finished compressing/uncompressing file(s)",success_list)
        end
        if failed_list.present?
          error_message_sender("Error when compressing/uncompressing file(s)",failed_list)
        end
      end # spawn
    end # if anything to do

    info_message = ""
    if to_compress.present?
      info_message += "#{view_pluralize(to_compress.size, "file")} being compressed in background.\n"
    end
    if to_uncompress.present?
      info_message += "#{view_pluralize(to_uncompress.size, "file")} being uncompressed in background.\n"
    end

    flash[:notice] = info_message unless info_message.blank?

    redirect_to :action => :index, :format => request.format.to_sym
  end



  # Convertion to/from archived only available for FileCollection.
  # On the filesystem an archived FileCollection:
  # abcd/*  ->  abcd/CONTENT.tar.gz
  # On the an Database archived FileCollection:
  # "abcd"  ->  "abcd" with 'archived' attribute set to true
  #
  # Also handles unarchiving TarArchives, just like create's
  # :archive => 'collection' option.
  def archive_management
    filelist    = params[:file_ids] || []

    # Validation of file list
    userfiles        = []
    skipped_messages = {}
    Userfile.find_accessible_by_user(filelist, current_user, :access_requested => :write).each do |userfile|
      unless userfile.is_a?(FileCollection) || userfile.is_a?(TarArchive)
        (skipped_messages["Not a FileCollection or TarArchive"] ||= []) << userfile
        next
      end

      if userfile.data_provider.read_only?
        (skipped_messages["Data Provider not writable"] ||= []) << userfile
        next
      end

      userfiles << userfile
    end

    # Skipped file notification
    if skipped_messages.present?
      flash[:error] = skipped_messages.map { |mes,list| "#{list.size} file collections skipped: #{mes}\n" }.join("")
    end

    # Nothing to do?
    if userfiles.blank?
      flash[:notice] = "No file collections selected for archiving or unarchiving."
      redirect_to :action => :index, :format => request.format.to_sym
      return
    end

    # Main processing in background
    CBRAIN.spawn_with_active_records(current_user, "ArchiveFile") do
      success_list = []
      failed_list  = {}

      userfiles.each_with_index do |userfile,i|
        if userfile.is_a?(TarArchive)
          $0 = "UnarchiveFile ID=#{userfile.id} #{i+1}/#{userfiles.size}\0"

          basename = userfile.name.split('.')[0]
          if current_user.userfiles.exists?(:name => basename, :data_provider_id => collection.data_provider_id)
            error_message = "Collection '#{collection.name}' already exists."
            break
          end

          collection      = userfile.dup.becomes(FileCollection)
          collection.name = basename

          userfile.sync_to_cache
          collection.extract_collection_from_archive_file(userfile.cache_full_path.to_s)
          userfile.destroy
        elsif userfile.archived?
          $0 = "UnarchiveFile ID=#{userfile.id} #{i+1}/#{userfiles.size}\0"
          error_message = userfile.provider_unarchive
        else
          $0 = "ArchiveFile ID=#{userfile.id} #{i+1}/#{userfiles.size}\0"
          error_message = userfile.provider_archive
        end

        if error_message.blank?
          success_list << userfile
        else
          (failed_list[error_message] ||= []) << userfile
        end
      end

      if success_list.present?
        notice_message_sender("Finished archiving/unarchiving file(s)",success_list)
      end
      if failed_list.present?
        error_message_sender("Error when archiving/unarchiving file(s)",failed_list)
      end
    end # spawn

    flash[:notice] = "#{view_pluralize(filelist.size, "file collection")} being archived/unarchived in background.\n"

    redirect_to :action => :index, :format => request.format.to_sym
  end


  private

  # Adds the persistent userfile ids to the params[:file_ids] argument
  def auto_add_persistent_userfile_ids #:nodoc:
    params[:file_ids] ||= []
    if params[:ignore_persistent].blank?
      params[:file_ids] = params[:file_ids] | current_session.persistent_userfile_ids_list
    end
  end

  # Verify that all files selected for an operation
  # are accessible by the current user.
  def permission_check #:nodoc:
    action_name = params[:action].to_s
    if params[:file_ids].blank? && action_name != 'manage_persistent'
      flash[:error] = "No files selected? Selection cleared.\n"
      redirect_to :action => :index, :format => request.format.to_sym
      return
    end

    yield
  rescue ActiveRecord::RecordNotFound
    flash[:error] += "\n" unless flash[:error].blank?
    flash[:error] ||= ""
    flash[:error] += "You don't have appropriate permissions to apply the selected action to this set of files."

    redirect_to :action => :index, :format => request.format.to_sym
  end

  #Extract files from an archive and register them in the database.
  #+archive_file_name+ is a path to an archive file (tar or zip).
  #+attributes+ is a hash of attributes for all the files,
  #they must contain at least user_id and data_provider_id
  def extract_from_archive(archive_file_name, file_type = nil, attributes = {}) #:nodoc:

    file_type = SingleFile if file_type && ! file_type <= SingleFile # just protect from classes outside of Userfile
    escaped_archivefile = archive_file_name.to_s.bash_escape # bash escaping

    # Check for required attributes
    data_provider_id    = attributes["data_provider_id"] ||
                          attributes[:data_provider_id]
    cb_error "No data provider ID supplied." unless data_provider_id

    user_id             = attributes["user_id"]  ||
                          attributes[:user_id]
    cb_error "No user ID supplied." unless user_id

    # Create content list
    all_files        = []
    if archive_file_name =~ /(\.tar.gz|\.tgz)$/i
      all_files = IO.popen("tar -tzf #{escaped_archivefile}") { |fh| fh.readlines.map(&:chomp) }
    elsif archive_file_name =~ /\.tar$/i
      all_files = IO.popen("tar -tf #{escaped_archivefile}") { |fh| fh.readlines.map(&:chomp) }
    elsif archive_file_name =~ /\.zip/i
      all_files = IO.popen("unzip -l #{escaped_archivefile}") { |fh| fh.readlines.map(&:chomp)[3..-3].map{ |line|  line.split[3]} }
    else
      cb_error "Cannot process file with unknown extension: #{archive_file_name}"
    end

    count = all_files.select{ |f| f !~ /\// }.size

    #max of 50 files can be added to the file list at a time.
    cb_error "Overflow: more than 50 files found in archive." if count > 50

    workdir = "/tmp/filecollection.#{Process.pid}"
    Dir.mkdir(workdir)
    Dir.chdir(workdir) do
      if archive_file_name =~ /(\.tar.gz|\.tgz)$/i
        system("tar -xzf #{escaped_archivefile}")
      elsif archive_file_name =~ /\.tar$/i
        system("tar -xf #{escaped_archivefile}")
      elsif archive_file_name =~ /\.zip/i
        system("unzip #{escaped_archivefile}")
      else
        FileUtils.remove_dir(workdir, true)
        cb_error "Cannot process file with unknown extension: #{archive_file_name}"
      end
    end

    # Prepare for extraction
    status           = :success
    successful_files = []
    failed_files     = []
    nested_files     = []

    all_files.each do |file_name|
      if file_name =~ /\//
        nested_files << file_name
      elsif Userfile.where(
              :name             => file_name,
              :user_id          => user_id,
              :data_provider_id => data_provider_id
            ).first
        failed_files << file_name
      else
        successful_files << file_name
      end
    end

    Dir.chdir(workdir) do
      successful_files.each do |file|
        local_file_type = file_type || Userfile.suggested_file_type(file)
        u = local_file_type.new(attributes)
        u.name = file
        if u.save
          u.cache_copy_from_local_file(file)
          u.size = File.size(file)
          u.save
        else
          status = :failed
        end
      end
    end

    FileUtils.remove_dir(workdir, true)

    # Report these values using new comm mechanism
    # [status, successful_files, failed_files, nested_files]
    report = "Based on the content of the archive we found:\n" +
             "#{successful_files.size.to_s} files successfully extracted;\n" +
             "#{failed_files.size.to_s} files failed extracting;\n" +
             "#{nested_files.size.to_s} files were ignored because they are nested in subdirectories.\n"
    if status == :success && failed_files.size == 0 && nested_files.size == 0
      Message.send_message(current_user.own_group,
        :message_type  => 'notice',
        :header  => "File extraction completed",
        :description  => "Your files have been extracted from archive '#{archive_file_name}'",
        :variable_text  => report
      )
    else
      Message.send_message(current_user.own_group,
        :message_type  => 'error',
        :header  => "File extraction failed",
        :description  => "Some errors occured while extracting files from archive '#{archive_file_name}'",
        :variable_text  => report
      )
    end

  end

  # This method creates a tar file of the userfiles listed
  # in +ulist+ (an array of Userfiles) such that
  # the tar structure is independent of the DP path
  # and owners. Each userfile basename 'x' will be
  # stored as a relative path 'user/dpname/x'. This
  # is needed when downloading a file, as a user is
  # allowed to have several files with the same names
  # on different DPs, and several users are allowed to
  # have files with the same names on the same DP.
  def create_relocatable_tar_for_userfiles(ulist,username) #:nodoc:
    timestamp    = Time.now.to_i.to_s[-4..-1]  # four digits long
    tmpdir       = Pathname.new("/tmp/dl.#{Process.pid}.#{timestamp}")
    tarfilename  = Pathname.new("/tmp/cbrain_files_#{username}.#{timestamp}.tar.gz") # must be outside the tmp work dir

    relpath_to_tar = []
    Dir.mkdir(tmpdir)
    Dir.chdir(tmpdir) do  # /tmpdir

      uids = ulist.group_by { |u1| u1.user_id }
      uids.each do |uid,userfiles_per_user|
        uname = User.find(uid).login
        Dir.mkdir(uname)
        Dir.chdir(uname) do # /tmpdir/user/dp

          dpids = userfiles_per_user.group_by { |u2| u2.data_provider_id }
          dpids.each do |dpid,userfiles_per_dp|
            dpname = DataProvider.find(dpid).name
            Dir.mkdir(dpname)
            Dir.chdir(dpname) do # /tmpdir/user/dp

              userfiles_per_dp.each do |u|
                fullpath = u.cache_full_path
                basename = fullpath.basename
                File.symlink(fullpath,basename) # /tmpdir/user/dp/basename -> fullpath
                relpath_to_tar << Pathname.new(uname) + dpname + basename
              end # each file per dp per user
            end # chdir tmpdir/user/dp
          end # each dp per user
        end # chdir tmpdir/user
      end # each user

      filelistname = "files_for_#{username}.#{Process.pid}.lst"
      File.open(filelistname,"w") do |fh|
        fh.write relpath_to_tar.join("\n")
        fh.write "\n"
      end

      system("tar -chf - -T #{filelistname.bash_escape} | gzip -c >#{tarfilename.to_s.bash_escape}")

    end # chdir tmpdir

    return tarfilename
  ensure
    FileUtils.remove_entry(tmpdir, true)
    return tarfilename
  end

  # Sort a list of files in "tree order" where
  # parents are listed just before their children.
  # It also keeps the original list's ordering
  # at each level. The method will set the level
  # of the files too, with 0 for the top level.
  #
  # The records processed here are not userfiles,
  # instead they are small arrays, originally with two
  # entries:
  #
  #   [ userfile_id, parent_id ]
  #
  # At the end, they get extended to five entries each:
  #
  #   [ userfile_id, parent_id, [ child1_id, child2_id... ], orig_idx, level ]
  def tree_sort_by_pairs(pairs = [])  # array of pairs: [ [ id, parent_id ], [ id, parent_id ] ... ]
    top         = [ nil, 999_999_999 ] # Dummy, to collect top level; ID is NIL!
    userfiles   = Array(pairs) + [ top ] # Note: so that by_id[nil] returns 'top'

    by_id       = {}        # id => userfile
    userfiles.each_with_index do |u,idx|
      u[2]        = nil
      by_id[u[0]] = u   # WE NEED TO USE THIS INSTEAD OF .parent !!!
      u[3]        = idx # original order in array
    end

    # Construct tree
    seen      = {}
    userfiles.each do |file|
      current  = file # probably not necessary
      track_id = file[0] # to detect loops
      while ! seen[current[0]]
        break if current == top
        seen[current[0]] = track_id
        parent_id     = current[1] # Can be nil! by_id[nil] will return 'top'
        parent        = by_id[parent_id] # Cannot use current.parent, as this would destroy its :tree_children
        parent      ||= top
        break if seen[parent[0]] && seen[parent[0]] == track_id # loop
        parent[2] ||= []
        parent[2] << current
        current = parent
      end
    end

    # Flatten tree
    all_tree_children_by_pairs(top,0) # sets top children's levels to '0'
  end

  # Returns an array will all children or subchildren
  # of the userfile, as contructed by tree_sort.
  # Optionally, sets the :level pseudo attribute
  # to all current children, increasing it down
  # the tree.
  def all_tree_children_by_pairs(top,level = nil) #:nodoc:
    return [] if top[2].blank?
    result = []
    top[2].sort { |a,b| a[3] <=> b[3] }.each do |child|
      child[4] = level if level
      result << child
      if child[2] # the 'if' optimizes one recursion out
        all_tree_children_by_pairs(child, level ? level+1 : nil).each { |c| result << c } # amazing! faster than += for arrays!
      end
    end
    result
  end

  # Reduce Userfile scoped according with the header scope
  # selected by user
  def header_scope(filters)
    header_scope = Userfile.scoped

    # Restrict by 'view all' or not
    filters["view_all"] ||= current_user.has_role?(:admin_user) ? 'off' : 'on'
    if filters["view_all"] == 'on'
      header_scope = Userfile.restrict_access_on_query(current_user, header_scope, :access_requested => :read)
    else
      header_scope = header_scope.where( :user_id => current_user.id )
    end

    # Filter by current project
    if current_project
      header_scope = header_scope.where( :group_id  => current_project.id )
    end

    # Filter by 'view hidden' or not
    unless filters["view_hidden"] == 'on'
      header_scope = header_scope.where( :hidden => false ) # show only the non-hidden files
    end

    header_scope
  end

  # Reduce Userfile scoped according with the filters
  # selected by user
  def filter_scope(filters,header_scope)
    # Prepare filters
    filters["filter_hash"]                 ||= {}
    filters["filter_custom_filters_array"] ||= []
    filters["filter_custom_filters_array"]  &= current_user.custom_filter_ids.map(&:to_s)
    filters["filter_tags_array"]           ||= []
    filters["filter_tags_array"]            &= current_user.available_tags.map{ |t| t.id.to_s }

    # Prepare custom filters
    custom_filter_tags = filters["filter_custom_filters_array"].map { |filter| UserfileCustomFilter.find(filter).tag_ids }.flatten.uniq

    # Prepare tag filters
    tag_filters        = filters["filter_tags_array"] + custom_filter_tags
    #Apply filters
    filtered_scope     = base_filtered_scope(header_scope)

    filters["filter_custom_filters_array"].each do |custom_filter_id|
      custom_filter    = UserfileCustomFilter.find(custom_filter_id)
      filtered_scope   = custom_filter.filter_scope(filtered_scope)
    end

    unless tag_filters.blank?
      filtered_scope   = filtered_scope.where( "((SELECT COUNT(DISTINCT tags_userfiles.tag_id) FROM tags_userfiles WHERE tags_userfiles.userfile_id = userfiles.id AND tags_userfiles.tag_id IN (#{tag_filters.join(",")})) = #{tag_filters.size})" )
    end
    return filtered_scope
  end

  # Sort a scoped Userfile according with the parameters
  # selected by user
  # Returns the sorted scoped Userfile and the set of joins
  # placed on it.
  # FIXME the sorting joins are required by some callers of
  # sorted_scope and both solutions (returning the joins and
  # recomputing them) are awkward
  def sorted_scope(filters,header_scope,filtered_scope)
    # Prepare sorting options
    filters["sort_hash"]["order"] ||= 'userfiles.name'

    # Apply the sorting parameters
    sorted_scope          = base_sorted_scope filtered_scope

    # Identify and add necessary table joins
    joins                 = []
    sort_table            = filters["sort_hash"]["order"].split(".")[0]
    if sort_table == "users" || current_user.has_role?(:site_manager)
      joins << :user
    end
    case sort_table
    when "groups"
      joins << :group
    when "data_providers"
      joins << :data_provider
    end
    sorted_scope = sorted_scope.joins(joins) unless joins.empty?

    # Add a secondary sorting column (name)
    sorted_scope = sorted_scope.order('userfiles.name') unless filters["sort_hash"]["order"] == 'userfiles.name'

    return sorted_scope, joins
  end

end
