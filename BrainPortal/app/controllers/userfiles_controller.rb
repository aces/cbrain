
#
# CBRAIN Project
#
# RESTful Userfiles Controller
#
# Original author: Tarek Sherif
#
# $Id$
#

require 'fileutils'

#RESTful controller for the Userfile resource.
class UserfilesController < ApplicationController

  Revision_info="$Id$"

  api_available

  before_filter :login_required
  around_filter :permission_check, :only  => [:download, :update_multiple, :delete_files, :create_collection, :change_provider, :quality_control]

  # GET /userfiles
  # GET /userfiles.xml
  def index #:nodoc:
    custom_filters = current_session.userfiles_custom_filters
    custom_filter_tags = []
    custom_filters.each{ |filter| custom_filter_tags |= UserfileCustomFilter.find_by_name(filter).tags}

    name_filters = current_session.userfiles_basic_filters + custom_filters.collect{ |filter| "custom:#{filter}" }
    format_filters, name_filters = name_filters.partition{|f| f =~ /^format:/} 
    tag_filters = current_session.userfiles_tag_filters + custom_filter_tags

    scope = Userfile.convert_filters_to_scope(name_filters)
    scope = scope.scoped(:conditions  => {:format_source_id  => nil})
    if current_project
      scope = scope.scoped(:conditions  => {:group_id  => current_project.id})
    end

    if current_session.view_all?
      if current_user.has_role? :site_manager
        scope = Userfile.restrict_site_on_query(current_user, scope)
      end
    else
      scope = Userfile.restrict_access_on_query(current_user, scope, :access_requested => :read)
    end

    scope = scope.scoped(
      :joins    => [ :user, :data_provider, :group ],
      :include   => :tags
    )
    
    current_session[:userfiles_sort_order] ||= 'userfiles.tree_sort'
    unless current_session.userfiles_sort_order == "userfiles.tree_sort"
      scope = scope.scoped(:order => "#{current_session.userfiles_sort_order} #{current_session.userfiles_sort_dir}")
    end
    
    @userfiles = scope
    
    @userfiles = Userfile.apply_tag_filters_for_user(@userfiles, tag_filters, current_user)

    format_filters.each do |fmt|
      @userfiles = @userfiles.select { |file| file.has_format? fmt.sub(/^format:/, "") }
    end

    if current_session[:userfiles_tree_sort] == "on"
      @userfiles = Userfile.tree_sort(@userfiles)
    end
    
    @userfiles_total = @userfiles.size
    
    @user_pref_page_length = (current_user.user_preference.other_options["userfiles_per_page"] || Userfile::Default_num_pages).to_i
    if current_session.paginate?
      @userfiles_per_page = @user_pref_page_length
    else
      @userfiles_per_page = 400 # even when not paginating, there's a limit!
    end
    @userfiles = Userfile.paginate(@userfiles, params[:page] || 1, @userfiles_per_page)

    @user_tags = current_user.tags.find(:all)
    @user_groups = current_user.available_groups(:all, :order => "type")
    @default_group  = SystemGroup.find_by_name(current_user.login).id
    @data_providers = DataProvider.find_all_accessible_by_user(current_user, :conditions => { :online => true } )
    @data_providers = @data_providers.select { |dp| ! dp.meta[:no_uploads] }
    @bourreaux      = Bourreau.find_all_accessible_by_user(current_user,     :conditions => { :online => true } )
    @preferred_bourreau_id = current_user.user_preference.bourreau_id
    
    #For the 'new' panel
    @userfile = Userfile.new(
      :group_id => SystemGroup.find_by_name(current_user.login).id
    )

    respond_to do |format|
      format.html
      format.js
      format.xml  { render :xml => @userfiles }
    end
  end

  def new_parent_child
    if params[:file_ids].blank?
      render :text  => "<span class=\"warning\">You must select at least one file to which you have write access.</span>"
      return
    end
    
    @userfiles = Userfile.find_accessible_by_user(params[:file_ids], current_user)
    
    render :action  => :new_parent_child, :layout  => false
  end
  
  def create_parent_child
    parent_id = params[:parent_id]
    child_ids = params[:child_ids]
    
    if parent_id.blank? || child_ids.blank?
      flash[:error] = "Must have both parent and children selected for this operation."
    else
      child_ids.delete(parent_id)
      @children = Userfile.find_accessible_by_user(params[:child_ids], current_user)
      @parent = Userfile.find_accessible_by_user(params[:parent_id], current_user)
      @children.each { |c| c.move_to_child_of(@parent) }
    end
    
    redirect_to :action => :index
  end

  ####################################################
  # Provides a way of accessing file contents in a way that is intelligent and customizable 
  # for each type of file supported in the platform
  # Each userfile subclass is in charge of defining its own content method 
  # which returns a hash that will either
  # 1) be used by render 
  # 2) or contain the :sendfile symbol which will instruct the system to stream the file 
  # 3) or contain the :gzip symbol which will adjust the content-encoding allowing 
  #    the browser to decode it. 
  # 
  # Other possibilities are also possible. Except for the impossible ones.
  ####################################################
  #GET /userfiles/1/content?option1=....optionN=...
  def content
    @userfile = Userfile.find_accessible_by_user(params[:id], current_user, :access_requested => :read)
    
    content = @userfile.content(params)

    
    if content
      if content[:sendfile]
        send_file content[:sendfile]
        return
      elsif content[:gzip]
        response.headers["Content-Encoding"] = "gzip" 
        render :text => content[:gzip]
      else
        render content
        return
      end
    else
      @userfile.sync_to_cache
      send_file @userfile.cache_full_path
    end
  
  end
  
  def display
    @userfile = Userfile.find_accessible_by_user(params[:id], current_user, :access_requested => :read)
    viewer_name = params[:viewerx] || params[:viewer]
    viewer      = @userfile.find_viewer(viewer_name)

    if viewer
      @partial = viewer.partial
    elsif viewer_name =~ /[\w\/]+/
      viewer_path = viewer_name.split("/")
      viewer_name = viewer_path.pop
      if File.exists?(RAILS_ROOT + "/app/views/userfiles/viewers/#{viewer_path.join("/")}/_#{viewer_name}.#{request.format.to_sym}.erb")
        @partial = viewer_path.push(viewer_name).join("/")
      end
    end
    
    if @partial
      if params[:apply_div] == "false"
        render  :partial  => "userfiles/viewers/#{@partial}"
      else
        render :action  => :display, :layout  => false
      end
    else
      render :text => "<div class=\"warning\">Could not find viewer #{params[:viewerx]}.</div>", :status  => "404"
    end
  end
  
  def show #:nodoc:
    @userfile = Userfile.find_accessible_by_user(params[:id], current_user, :access_requested => :read)
    
    # This allows the user to manually trigger the syncing to the Portal's cache
    @sync_status = 'ProvNewer' # same terminology as in SyncStatus
    state = @userfile.local_sync_status
    @sync_status = state.status if state
    @default_viewer = @userfile.viewers.first

    @log  = @userfile.getlog rescue nil
  end
  
  # GET /userfiles/1/edit
  def edit  #:nodoc:
    @userfile = Userfile.find_accessible_by_user(params[:id], current_user, :access_requested => :write)

    # This allows the user to manually trigger the syncing to the Portal's cache
    @sync_status = 'ProvNewer' # same terminology as in SyncStatus
    state = @userfile.local_sync_status
    @sync_status = state.status if state

    @user_groups = current_user.available_groups(:all, :order => "type")

    @tags = current_user.tags.find(:all)

    @log  = @userfile.getlog rescue nil
  end
  
  # Triggers a background synchronization of a file to the
  # Portal's local cache
  def sync_to_cache #:nodoc:
     @userfile = Userfile.find_accessible_by_user(params[:id], current_user, :access_requested => :read)
     state = @userfile.local_sync_status
     @sync_status = 'ProvNewer'
     @sync_status = state.status if state
     
     if @sync_status !~ /^To|InSync|Corrupted/
       CBRAIN.spawn_with_active_records(current_user, "Synchronization of #{@userfile.name}") do
         @userfile.sync_to_cache
         @userfile.set_size
       end # spawn
     end
     
     redirect_to :action  => :show
  end
  
  def sync_multiple
    @userfiles = Userfile.find_accessible_by_user(params[:file_ids], current_user, :access_requested => :read)
    
    CBRAIN.spawn_with_active_records(current_user, "Synchronization of #{@userfiles.size} files.") do
      @userfiles.each do |userfile|
        state = userfile.local_sync_status
        sync_status = 'ProvNewer'
        sync_status = state.status if state
        
        if sync_status !~ /^To|InSync|Corrupted/
          userfile.sync_to_cache
          userfile.set_size  
        end
      end
    end # spawn
    
    redirect_to :action  => :index
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
  def create

    flash[:error]  ||= ""
    flash[:notice] ||= ""
    redirect_path = params[:redirect_to] || {:action  => :index}

    # Get the upload stream object
    upload_stream = params[:upload_file]   # an object encoding the file data stream
    if upload_stream.blank?
      redirect_to redirect_path
      return
    end

    # Get the data provider for the destination files.
    data_provider_id = params[:data_provider_id]
    if data_provider_id.blank?
      data_provider_id = DataProvider.find_first_online_rw(current_user).id
    end

    # Save raw content of the file; we don't know yet
    # whether it's an archive or not, or if we'll extract it etc.
    basename               = File.basename(upload_stream.original_filename)
    unless Userfile.is_legal_filename?(basename)
      flash[:error] = "This filename, '#{basename}', is not acceptable. It contains invalid characters."
      redirect_to redirect_path
      return
    end

    tmpcontentfile         = "/tmp/#{Process.pid}-#{rand(10000).to_s}-#{basename}"

    # Decide what to do with the raw data
    if params[:archive] == 'save'  # the simplest case first

      userfile = SingleFile.new(
                   params[:userfile].merge(
                     :name             => basename,
                     :user_id          => current_user.id,
                     :data_provider_id => data_provider_id,
                     :tag_ids          => params[:tags]
                   )
                 )

      if ! userfile.save
        flash[:error]  += "File '#{basename}' could not be added.\n"
        userfile.errors.each do |field, error|
          flash[:error] += field.capitalize + " " + error + ".\n"
        end
        redirect_to redirect_path
        return
      end

      flash[:notice] += "File '#{basename}' being added in background."

      CBRAIN.spawn_with_active_records(current_user,"Upload of SingleFile") do
        localpath = upload_stream.local_path rescue "" # optimize for large files
        if localpath.blank?
          begin
            File.open(tmpcontentfile, "w") { |io| io.write(upload_stream.read) }
            userfile.cache_copy_from_local_file(tmpcontentfile)
            userfile.size = File.size(tmpcontentfile) rescue 0
          ensure
            File.delete(tmpcontentfile) rescue true
          end
        else
          userfile.cache_copy_from_local_file(localpath)
          userfile.size = File.size(userfile.cache_full_path) rescue 0
        end
        userfile.save
        userfile.addlog_context(self,"Uploaded by #{current_user.login}")
        current_user.addlog_context(self,"Uploaded SingleFile '#{userfile.name}', #{userfile.size} bytes")
        Message.send_message(current_user,
                             :message_type  => 'notice', 
                             :header  => "SingleFile Uploaded", 
                             :variable_text  => "#{userfile.name} [[View][/userfiles/#{userfile.id}]]"
                             )
      end # spawn
      
      redirect_to redirect_path
      return
    end # save

    # We will be processing some archive file.
    # First, check for supported extensions
    if basename !~ /(\.tar|\.tgz|\.tar.gz|\.zip)$/i
      flash[:error] += "Error: file #{basename} does not have one of the supported extensions: .tar, .tar.gz, .tgz or .zip.\n"
      redirect_to redirect_path
      return
    end

    # Create a collection
    if params[:archive] =~ /collection/

      collection_name = basename.split('.')[0]  # "abc"
      if current_user.userfiles.exists?(:name => collection_name, :data_provider_id => data_provider_id)
        flash[:error] = "Collection '#{collection_name}' already exists.\n"
        redirect_to redirect_path
        return
      end

      collectionType = params[:archive] =~/civet/i ? CivetCollection : FileCollection

      collection = collectionType.new(
        params[:userfile].merge(
          :name              => collection_name,
          :user_id           => current_user.id,
          :data_provider_id  => data_provider_id,
          :tag_ids           => params[:tags]
        )
      )
      
      if collection.save

        CBRAIN.spawn_with_active_records(current_user,"FileCollection Extraction") do
          begin
            File.open(tmpcontentfile, "w") { |io| io.write(upload_stream.read) }
            collection.extract_collection_from_archive_file(tmpcontentfile)
            Message.send_message(current_user,
                                  :message_type  => 'notice', 
                                  :header  => "Collection Uploaded", 
                                  :variable_text  => collection.name
                                  )
          ensure
            File.delete(tmpcontentfile) rescue true
          end
        end # spawn
      
        flash[:notice] = "Collection '#{collection_name}' created."
        current_user.addlog_context(self,"Uploaded FileCollection '#{collection_name}'")
        redirect_to redirect_path
      else
        flash[:error] = "Collection '#{collection_name}' could not be created.\n"
        collection.errors.each do |field, error|
          flash[:error] += field.capitalize + " " + error + ".\n"
        end
        redirect_to redirect_path
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
    CBRAIN.spawn_with_active_records(current_user,"Archive extraction") do
      begin
        File.open(tmpcontentfile, "w") { |io| io.write(upload_stream.read) }
        extract_from_archive(tmpcontentfile,attributes) # generates its own Messages
      ensure
        File.delete(tmpcontentfile) rescue true
      end
    end # spawn

    flash[:notice] += "Your files are being extracted and added in background."
    redirect_to redirect_path
  end

  # PUT /userfiles/1
  # PUT /userfiles/1.xml
  def update  #:nodoc:
    @userfile = Userfile.find_accessible_by_user(params[:id], current_user, :access_requested => :read)

    flash[:notice] ||= ""
    flash[:error]  ||= ""

    attributes = params[:userfile] || {}

    old_name = @userfile.name
    new_name = attributes[:name] || old_name

    if ! Userfile.is_legal_filename?(new_name)
      flash[:error] += "Error: filename '#{new_name}' is not acceptable (illegal characters?)."
      new_name = old_name
    end

    attributes[:name] = old_name # we must NOT rename the file yet

    if params[:file_type]
      unless @userfile.update_file_type(params[:file_type])
        flash[:error] += "\nCould not update file format."
      end
    end

    @userfile.set_tags_for_user(current_user, params[:tag_ids])
    respond_to do |format|
      if @userfile.update_attributes(attributes)
        if new_name != old_name
           if @userfile.provider_rename(new_name)
              @userfile.save
           end
        end
        flash[:notice] += "#{@userfile.name} successfully updated."
        format.html { redirect_to(:action  => 'edit') }
        format.xml  { head :ok }
      else
        flash[:error] += "#{@userfile.name} has NOT been updated."
        @userfile.name = old_name
        @tags = current_user.tags
        @user_groups = current_user.available_groups(:all, :order => "type")
        format.html { render :action  => 'edit' }
        format.xml  { render :xml => @userfile.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  # Updated tags, groups or group-writability flags for several
  # userfiles.
  def update_multiple
    filelist    = params[:file_ids] || []
    operation = case params[:commit].to_s
                   # Critical! Case values much mach label of submit button!
                   when "Update Tags"
                     ['set_tags_for_user', current_user, params[:tags]]
                   when "Update Projects"
                     ["update_attributes", {:group_id => params[:userfile][:group_id]}]
                   when "Update Permissions" 
                     ["update_attributes", {:group_writable => params[:userfile][:group_writable]}]
                   when "Update"
                     ["update_file_type", params[:file_type]]
                end

    unless operation
      flash[:error] = "No operation to perform."
      redirect_action = params[:redirect_action] || {:action => :index, :format => request.format.to_sym}
      redirect_to redirect_action
      return
    end

    access_requested = params[:commit] == "Update Tags" ? :read : :write

    success_count = 0
    failure_count = 0
    
    Userfile.find_accessible_by_user(filelist, current_user, :access_requested => access_requested).each do |userfile|
     if userfile.send(*operation)
        success_count += 1
      else
        failure_count +=1
      end
    end
    
    if success_count > 0
      flash[:notice] = "#{params[:commit].to_s.humanize} successful for #{@template.pluralize(success_count, "files")}."
    end
    if failure_count > 0
      flash[:error] =  "#{params[:commit].to_s.humanize} unsuccessful for #{@template.pluralize(failure_count, "files")}."
    end
    
    redirect_action = params[:redirect_action] || {:action => :index, :format => request.format.to_sym}
    redirect_to redirect_action
  end
  
  def quality_control
    @filelist      = params[:file_ids] || []
    @current_index = params[:index]    || -1    
    
    @current_index = @current_index.to_i
    
    if @current_index >=  0 && params[:commit] != "Skip"
      @current_userfile = Userfile.find_accessible_by_user(@filelist[@current_index], current_user)
      tag_ids = params[:tag_ids] || []
      case params[:commit]
      when "Pass"
        tag_ids |= [@current_user.tags.find_or_create_by_name_and_user_id("QC_PASS", current_user.id).id.to_s]
      when "Fail"
        tag_ids |= [@current_user.tags.find_or_create_by_name_and_user_id("QC_FAIL", current_user.id).id.to_s]
      when "Unknown"
        tag_ids |= [@current_user.tags.find_or_create_by_name_and_user_id("QC_UNKNOWN", current_user.id).id.to_s]
      end
      @current_userfile.set_tags_for_user(current_user, tag_ids)
    end
    
    if @current_index + 1 < @filelist.size
      @current_index += 1
      @userfile = Userfile.find_accessible_by_user(@filelist[@current_index], current_user)
    else
      flash[:notice] = "QC done."
      redirect_to "/userfiles"
      return
    end     
  end
  
  #Create a collection from the selected files.
  def create_collection
    filelist    = params[:file_ids] || []
    if current_project
      file_group = current_project.id
    else
      file_group = current_user.own_group.id
    end
    
    collection = FileCollection.new(
        :user_id          => current_user.id,
        :group_id         => file_group,
        :data_provider    => DataProvider.find(params[:data_provider_id])
        )

    CBRAIN.spawn_with_active_records(current_user,"Collection Merge") do
      result = collection.merge_collections(Userfile.find_accessible_by_user(filelist, current_user, :access_requested  => :read))
      if result == :success
        Message.send_message(current_user,
                            :message_type  => 'notice', 
                            :header  => "Collections Merged", 
                            :variable_text  => "[[#{collection.name}][/userfiles/#{collection.id}]]"
                            )
      else
        Message.send_message(current_user,
                            :message_type  => 'error', 
                            :header  => "Collection could not be merged.", 
                            :variable_text  => "There was a collision among the file names."
                            )
      end
    end # spawn

    flash[:notice] = "Collection #{collection.name} is being created in background."
    redirect_to :action => :index, :format => request.format.to_sym
    
  end
  
  #Copy or move files to a new provider.
  def change_provider
    if params[:commit] == 'Move Files'
      task      = 'move'
    elsif params[:commit] == 'Copy Files'
      task      = 'copy'
    end
    
    filelist    = params[:file_ids] || []
    # Default message keywords for 'move'
    word_move  = 'move'
    word_moved = 'moved'
    if task == 'copy'  # switches to 'copy' mode, so adjust the words
      word_move  = 'copy'
      word_moved = 'copied'
    end

    data_provider_id = params[:data_provider_id]
    new_provider = DataProvider.find_accessible_by_user(data_provider_id,current_user, :conditions =>  {:online => true, :read_only => false})

    unless new_provider
      flash[:error] = "Data provider #{data_provider_id} not accessible.\n"
      redirect_to :action => :index, :format => request.format.to_sym
      return
    end

    CBRAIN.spawn_with_active_records(current_user,"#{word_move.capitalize} To Other Data Provider") do
      moved_list  = []
      failed_list = {}
      filelist.each do |id|
        begin
          u = Userfile.find_accessible_by_user(id, current_user,
                            :readonly         => (task == 'copy'),
                            :access_requested => (task == 'copy' ? :read : :write) )
          next unless u
          orig_provider = u.data_provider
          next if orig_provider.id == data_provider_id
          res = nil
          if task == 'move'
            raise "Not owner." unless u.has_owner_access?(current_user)
            res = u.provider_move_to_otherprovider(new_provider)
          else
            # NOTE! DO NOT SAVE 'u' HERE, WE CHANGE THE ATTRIBUTES SO
            # THAT THE COPY METHOD WILL CHECK FOR COLLISIONS BUT THEY
            # SHOULD NOT STAY LIKE THAT! (FOR SAFETY, WE HAVE :readonly IN EFFECT)
            u.user_id    = current_user.id
            u.group_id   = current_project ? current_project.id : current_user.own_group.id
            u.created_at = Time.now
            res = u.provider_copy_to_otherprovider(new_provider)
            u=Userfile.find(id) # RELOAD IT AND CLEAR :readonly !
          end
          raise "File collision: there is already such a file on the other provider." unless res
          u.addlog "#{word_moved.capitalize} from data provider '#{orig_provider.name}' to '#{new_provider.name}'"
          res.addlog "#{word_moved.capitalize} from data provider '#{orig_provider.name}' to '#{new_provider.name}'" if task == 'copy'
          u.save
          moved_list << u
        rescue => e
          if u.is_a?(Userfile)
            err_message = e.message
            failed_list[err_message] ||= []
            failed_list[err_message] << u
          else
            raise e
          end
        end
      end

      if moved_list.size > 0
        Message.send_message(current_user,
                            :message_type  => 'notice', 
                            :header  => "Files #{word_moved} to #{new_provider.name}",
                            :variable_text  => "List:\n" + moved_list.map { |u| "[[#{u.name}][/userfiles/#{u.id}]]\n" }.join("")
                            ) 
      end

      if failed_list.size > 0
        report = ""
        failed_list.each do |message,userfiles|
          report += "Failed because: #{message}\n"
          report += userfiles.map { |u| "[[#{u.name}][/userfiles/#{u.id}]]\n" }.join("")
        end
        Message.send_message(current_user,
                            :message_type  => 'error', 
                            :header        => "Some files could not be #{word_moved} to #{new_provider.name}",
                            :variable_text => report
                            )
      end

    end # spawn

    flash[:notice] = "Your files are being #{word_moved} in the background.\n"
    redirect_to :action => :index, :format => request.format.to_sym
  end
  
  #Delete the selected files.
  def delete_files
    filelist    = params[:file_ids] || []
    
    deleted_count      = 0
    unregistered_count = 0
  
    Userfile.find_accessible_by_user(filelist, current_user, :access_requested => :write).each do |userfile|
      basename = userfile.name
      if userfile.data_provider.is_browsable?
        unregistered_count += 1
      else
        deleted_count += 1
      end
      userfile.destroy
    end
  
    if deleted_count > 0
      flash[:notice] = "#{@template.pluralize(deleted_count, "files")} deleted.\n"
    end
    if unregistered_count > 0
      flash[:notice] = "#{@template.pluralize(unregistered_count, "files")} unregistered.\n"
    end
    
    redirect_to :action => :index, :format => request.format.to_sym
  end
  

  #Dowload the selected files.
  def download
    filelist           = params[:file_ids] || []
    specified_filename = params[:specified_filename]
    
    if ! specified_filename.blank?
      if ! Userfile.is_legal_filename?(specified_filename)
          flash[:error] = "Error: filename '#{specified_filename}' is not acceptable (illegal characters?)."
          redirect_to :action => :index, :format =>  request.format.to_sym
          return
      else
        specified_filename = "#{specified_filename}.tar.gz"
      end
    else
      is_blank = true
      timestamp    = Time.now.to_i.to_s[-4..-1]  # four digits long
      specified_filename = "cbrain_files_#{current_user.login}.#{timestamp}.tar.gz"
    end
    
    if filelist.size == 1 && Userfile.find_accessible_by_user(filelist[0], current_user, :access_requested => :read).is_a?(SingleFile)
      userfile = Userfile.find_accessible_by_user(filelist[0], current_user, :access_requested => :read)
      userfile.sync_to_cache
      fullpath = userfile.cache_full_path
      specified_filename.sub!(/.tar.gz$/,"") unless specified_filename.blank?
      send_file fullpath, :stream => true, :filename => is_blank ? fullpath.basename : specified_filename        
    else
      userfiles_list = filelist.collect do |id|
        u = Userfile.find_accessible_by_user(id, current_user, :access_requested => :read)
        next unless u
        u.sync_to_cache
        u
      end
      if userfiles_list.size == 0
        flash[:notice] = "No filenames selected for download."
        redirect_to :action => :index, :format =>  request.format.to_sym
        return
      end
      tarfile = create_relocatable_tar_for_userfiles(userfiles_list,current_user.login)
      send_file tarfile, :stream  => true, :filename => specified_filename
      CBRAIN.spawn_fully_independent("DL clean #{current_user.login}") do
        sleep 300
        File.unlink(tarfile)
      end
    end
  end

  #Extract a file from a collection and register it separately
  #in the database.
  def extract_from_collection
    success = failure = 0

    unless params[:file_ids] && params[:file_ids].size > 0
      flash[:notice] = "No files selected for extraction"
      redirect_to :action  => :edit
      return
    end

    collection = FileCollection.find_accessible_by_user(params[:id], current_user, :access_requested  => :read)
    collection_path = collection.cache_full_path
    data_provider_id = collection.data_provider_id
    params[:file_ids].each do |file|
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
  def compress 
    filelist    = params[:file_ids] || []
    
    to_compress        = []
    to_uncompress      = []
    skipped_messages   = {}

    Userfile.find_accessible_by_user(filelist, current_user, :access_requested => :write).each do |userfile|

      unless userfile.is_a?(SingleFile)
        (skipped_messages["Not a SingleFile"] ||= []) << userfile
        next
      end
      if userfile.data_provider.read_only?
        (skipped_messages["Data Provider not writable"] ||= []) << userfile
        next
      end

      basename = userfile.name

      if basename =~ /\.gz$/i
        destbase = basename.sub(/\.gz$/i,"")
      else
        destbase = basename + ".gz"
      end

      if Userfile.find(:first, :conditions => {
                                 :name             => destbase,
                                 :user_id          => userfile.user_id,
                                 :data_provider_id => userfile.data_provider_id
                               })
        (skipped_messages["Filename collision"] ||= []) << userfile
        next
      end

      if basename =~ /\.gz$/i
        to_uncompress << [ userfile, :uncompress, destbase ]
      else
        to_compress   << [ userfile, :compress,   destbase ]
      end

    end

    if to_compress.size > 0 || to_uncompress.size > 0
      CBRAIN.spawn_with_active_records(current_user, "Compression") do
        error_messages = ""
        done_ok = []
        (to_compress + to_uncompress).each do |u_triplet|
          userfile,do_what,destbase = *u_triplet
          begin
            if ! userfile.provider_rename(destbase)
              error_messages += "Could not do basic renaming to #{destbase}'.\n"
              next
            end
            userfile.sync_to_cache
            SyncStatus.ready_to_modify_cache(userfile) do
              full_after = userfile.cache_full_path.to_s
              full_tmp   = "#{full_after}+#{$$}+#{Time.now.to_i}"
              command = (do_what == :compress) ? "gzip" : "gunzip"
              system("#{command} -c < '#{full_after}' > '#{full_tmp}'")
              File.rename(full_tmp,full_after) # crush it
            end
            userfile.sync_to_provider
            done_ok << userfile
          rescue => e
            error_messages += "Internal error (un)compresssing for '#{userfile.name}': #{e.message}.\n";
          end
        end
        Message.send_message(current_user,
                             :message_type => 'notice',
                             :header       => "Finished compressing or uncompressing files." + (error_messages.blank? ? "" : " (with some errors)"),
                             :variable_text => done_ok.map { |u| "[[#{u.name}][/userfiles/#{u.id}]]" }.join(", ") + "\n" + error_messages
                            )
      end # spawn
    end # if anything to do
  
    info_message = ""
    if to_compress.size > 0
      info_message += "#{@template.pluralize(to_compress.size, "files")} being compressed in background.\n"
    end
    if to_uncompress.size > 0
      info_message += "#{@template.pluralize(to_uncompress.size, "files")} being uncompressed in background.\n"
    end
    skipped_messages.each do |mess,userfiles|
      info_message += "Warning: some files were skipped; Reason: #{mess}; Files: "
      info_message += userfiles.map { |u| "#{u.name}" }.join(", ") + "\n"
    end

    flash[:notice] = info_message unless info_message.blank?
    
    redirect_to :action => :index, :format => request.format.to_sym
  end

  private
  
  # Verify that all files selected for an operation
  # are accessible by the current user.
  def permission_check
    if params[:file_ids].blank?
      flash[:error] = "No file selected? Selection cleared.\n"
      redirect_to :action => :index, :format => request.format.to_sym
      return
    end
    action_name = params[:action].to_s
    if action_name == "update_multiple"
      action_name = params[:commit] + " on"
    end
    
    yield
  rescue ActiveRecord::RecordNotFound => e
    flash[:error] += "\n" unless flash[:error].blank?
    flash[:error] ||= ""
    flash[:error] += "You don't have appropriate permissions to apply the selected action to this set of files."

    redirect_to :action => :index, :format => request.format.to_sym
  end
  
  #Extract files from an archive and register them in the database.
  #The first argument is a path to an archive file (tar or zip).
  #The second argument is a hash of attributes for all the files,
  #they must contain at least user_id and data_provider_id
  def extract_from_archive(archive_file_name,attributes = {}) #:nodoc:

    escaped_archivefile = archive_file_name.gsub("'", "'\\\\''")

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
        system("tar -xzf '#{escaped_archivefile}'")
      elsif archive_file_name =~ /\.tar$/i
        system("tar -xf '#{escaped_archivefile}'")
      elsif archive_file_name =~ /\.zip/i
        system("unzip '#{escaped_archivefile}'")
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
      elsif Userfile.find(:first, :conditions => {
                                     :name             => file_name,
                                     :user_id          => user_id,
                                     :data_provider_id => data_provider_id
                                     }
                         )
        failed_files << file_name
      else
        successful_files << file_name
      end
    end

    Dir.chdir(workdir) do
      successful_files.each do |file|
        u = SingleFile.new(attributes)
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

      system("tar -chf - -T #{filelistname} | gzip -c >#{tarfilename}")

    end # chdir tmpdir

    return tarfilename
  ensure
    FileUtils.remove_entry(tmpdir, true)
    return tarfilename
  end

end
