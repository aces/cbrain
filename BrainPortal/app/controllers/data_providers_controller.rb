
#
# CBRAIN Project
#
# Data Provider controller for the BrainPortal interface
#
# Original author: Pierre Rioux
#
# $Id$
#

#Restful controller for the DataProvider resource.
class DataProvidersController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__]

  api_available :except => [:disk_usage, :cleanup]

  before_filter :login_required
  before_filter :manager_role_required, :only => [:new, :create]
   
  def index #:nodoc:
    @filter_params["sort_hash"]["order"] ||= "data_providers.name"
    
    @header_scope   = DataProvider.find_all_accessible_by_user(current_user)
    @data_providers = base_filtered_scope @header_scope.includes(:user, :group)

    if current_user.has_role? :admin
      @filter_params['details'] = 'on' unless @filter_params.has_key?('details')
    end

    respond_to do |format|
      format.html
      format.xml { render :xml  => @data_providers }
      format.js
    end
  end

  # GET /data_providers/1
  # GET /data_providers/1.xml
  def show  #:nodoc:
    data_provider_id = params[:id]
    @provider        = DataProvider.find(data_provider_id)

    cb_notice "Provider not accessible by current user." unless @provider.can_be_accessed_by?(current_user)

    @ssh_keys = get_ssh_public_keys

    respond_to do |format|
      format.html # show.html.erb
      format.xml { render :xml => @provider }
    end
  end

  def new #:nodoc:
    provider_group_id = ( current_project && current_project.id ) || current_user.own_group.id
    @provider = DataProvider.new( :user_id   => current_user.id,
                                  :group_id  => provider_group_id,
                                  :online    => true,
                                  :read_only => false
                                )
    
    @typelist = get_type_list
    @ssh_keys = get_ssh_public_keys
    
    render :partial => "new"
  end

  def create #:nodoc:
    fields    = params[:data_provider] || {}
    subtype   = fields.delete(:type)

    errors = {}
  
    if subtype.blank?
      errors[:type] = "must be specified."
      subclass = DataProvider
    else
      subclass  = Class.const_get(subtype) rescue NilClass
      if subtype == "DataProvider" || ! (subclass < DataProvider)
        errors[:base] = "Type is not a valid Data Provider class"
        subclass = DataProvider
      end
    end
    
    @provider = subclass.new(fields)
    @provider.user_id ||= current_user.id # disabled field in form DOES NOT send value!
    
    if errors.empty? && @provider.save
      add_meta_data_from_form(@provider, [:must_move, :must_erase, :no_uploads, :no_viewers])
    else
      errors.each do |attr, msg|
        @provider.errors.add(attr, msg)
      end
    end
    
    @typelist = get_type_list
    @ssh_keys = get_ssh_public_keys

    if @provider.errors.empty?
      flash[:notice] = "Provider successfully created."
      respond_to do |format|
        format.js  { redirect_to :action => :index, :format => :js  }
        format.xml { render :xml  => @provider }
      end
    else
      respond_to do |format|
        format.js  { render :partial  => "shared/failed_create", :locals => {:model_name => "data_provider"} }
        format.xml { render :xml  => @provider.errors, :status  => :unprocessable_entity }
      end
    end
  end

  def update #:nodoc:
    @user     = current_user
    id        = params[:id]
    @provider = DataProvider.find(id)

    unless @provider.has_owner_access?(current_user)
       flash[:error] = "You cannot edit a provider that you do not own."
       respond_to do |format|
        format.html { redirect_to :action => :show }
        format.xml  { head :forbidden }
       end
       return
    end

    fields    = params[:data_provider] || {}
    subtype   = fields.delete(:type)

    @provider.update_attributes(fields)

    if @provider.errors.empty?
      add_meta_data_from_form(@provider, [:must_move, :must_erase, :no_uploads, :no_viewers])
      flash[:notice] = "Provider successfully updated."
      respond_to do |format|
        format.html { redirect_to :action => :show }
        format.xml  { render :xml  => @provider }
      end   
    else
      @provider.reload
      @ssh_keys = get_ssh_public_keys
      respond_to do |format|
        format.html { redirect_to :action => 'show' }
        format.xml  { render :xml  => @provider.errors, :status  => :unprocessable_entity }
      end
    end
  end

  def destroy #:nodoc:
    @data_provider  = DataProvider.find_accessible_by_user(params[:id], current_user)

    unless @data_provider.has_owner_access?(current_user)
      raise CbrainDeleteRestrictionError.new("You cannot remove a provider that you do not own.")
    end
    
    @data_provider.destroy
    
    flash[:notice] = "Provider successfully deleted."
    
    respond_to do |format|
      format.js { redirect_to :action => :index, :format => :js }
      format.xml { head :ok }  
    end
  rescue ActiveRecord::DeleteRestrictionError => e
    flash[:error]  = "Provider not destroyed: #{e.message}"
    
    respond_to do |format|
      format.js  { redirect_to :action => :index}
      format.xml { head :conflict }
    end
  end
  
  def is_alive #:nodoc:
    @provider = DataProvider.find_accessible_by_user(params[:id], current_user)
    is_alive =  @provider.is_alive?
    respond_to do |format|
      format.html { render :text  => red_if( ! is_alive, "<span>Yes</span>".html_safe, "No" ) }
      format.xml { render :xml  => { :is_alive  => is_alive }  }
    end  
  end

  def dp_disk_usage #:nodoc:
    @providers = DataProvider.find_all_accessible_by_user(current_user).all

    # Users in statistics table
    userlist         = current_user.available_users.all

    # Create disk usage statistics table
    stats_options = { :users            => userlist,
                      :providers        => @providers,
                    }
    @report_stats    = ModelsReport.dp_usage_statistics(stats_options)

    # Keys and arrays into statistics tables, for HTML output
    @report_dps_all     = @report_stats['!dps+all?!']      # DPs   + 'all'?
    @report_users_all   = @report_stats['!users+all?!']    # users + 'all'?
  end

  def dp_access #:nodoc:
    @providers = DataProvider.find_all_accessible_by_user(current_user).all.sort { |a,b| a.name <=> b.name }
    @users     = current_user.available_users.all.sort { |a,b| a.login <=> b.login }
  end

  #Browse the files of a data provider.
  #This action is only available for data providers that are browsable.
  #Both registered and unregistered files will appear in the list. 
  def browse
    @provider = DataProvider.find_accessible_by_user(params[:id], current_user)

    @filter_params["browse_hash"] ||= {}
    @per_page = @filter_params["browse_hash"]["per_page"]
    validate_pagination_values # validates @per_page and @current_page
    as_user_id = params[:as_user_id].presence || @filter_params["browse_hash"]["as_user_id"].presence || current_user.id
    @as_user = current_user.available_users.where(:id => as_user_id).first || current_user
    @filter_params["browse_hash"]["as_user_id"] = @as_user.id.to_s

    unless @provider.is_browsable?
      flash[:error] = "You cannot browse this provider."
      respond_to do |format|
        format.html { redirect_to :action => :index }
        format.xml  { render :xml  => { :error  =>  flash[:error] }, :status => :forbidden }
      end
      return
    end

    begin
      # [ base, size, type, mtime ]
      @fileinfolist = get_recent_provider_list_all(params[:refresh], @as_user)
    rescue => e
      flash[:error] = 'Cannot get list of files. Maybe the remote directory doesn\'t exist or is locked?' #emacs fails to parse this properly so I switched to single quotes. 
      Message.send_internal_error_message(User.find_by_login('admin'), "Browse DP exception, YAML=#{YAML.inspect}", e, params) rescue nil
      respond_to do |format|
        format.html { redirect_to :action => :index }
        format.xml { render :xml  => { :error  =>  flash[:error] }, :status  => :unprocessable_entity}
      end
      return
    end

    # Let's add three more custom attributes:
    # - the userfile if the file is already registered
    # - the state_ok flag that tell whether or not it's OK to register/unregister
    # - a message.
    if @fileinfolist.size > 0
       @fileinfolist[0].class.class_eval("attr_accessor :userfile, :state_ok, :message")
    end

    registered_files = Userfile.where( :data_provider_id => @provider.id ).index_by(&:name)

    @fileinfolist.each do |fi|
      fi_name  = fi.name
      fi_size  = fi.size
      fi_type  = fi.symbolic_type
      fi_mtime = fi.mtime

      fi.userfile = nil
      fi.message  = ""
      fi.state_ok = false

      registered = registered_files[fi_name]
      if registered
        fi.userfile = registered # the userfile object itself
        if ((fi_type == :symlink)                                    ||
            (fi_type == :regular    && registered.is_a?(SingleFile)) ||
            (fi_type == :directory  && registered.is_a?(FileCollection)))
          fi.message = ""
          fi.state_ok = true
        else
          fi.message = "Conflicting types!"
          fi.state_ok = false
        end
        next
      end

      # Unregistered.
      if Userfile.is_legal_filename?(fi_name)
        fi.message = ""
        fi.state_ok = true
      else
        fi.message = "Illegal characters in filename."
        fi.state_ok = false
      end

    end

    if params[:search].present?
      search_term = params[:search].to_s.downcase
      params[:page] = 1
      @fileinfolist = @fileinfolist.select{|file| file.name.to_s.downcase.index(search_term)}
    end

    @file_count   = @fileinfolist.count
    unless request.format.to_sym == :xml
      @fileinfolist = @fileinfolist.paginate(:page => @current_page, :per_page => @per_page) 
    end
    
    respond_to do |format|
      format.html
      format.xml { render :xml  => @fileinfolist }
      format.js
    end

  end

  #Register a list of files into the system.
  #The files' meta data will be saved as Userfile resources.
  def register
    @provider  = DataProvider.find_accessible_by_user(params[:id], current_user)

    @filter_params["browse_hash"] ||= {}
    as_user_id = params[:as_user_id].presence || @filter_params["browse_hash"]["as_user_id"].presence || current_user.id
    @as_user = current_user.available_users.where(:id => as_user_id).first || current_user
    @filter_params["browse_hash"]["as_user_id"] = @as_user.id.to_s

    unless @provider.is_browsable?
      flash[:error] = "You cannot register files from this provider."
      respond_to do |format|
        format.html { redirect_to :action => :index }
        format.xml  { render :xml  => { :error  =>  flash[:error] }, :status  => :forbidden }
      end
      return
    end

    basenames = params[:basenames] || []
    filetypes = params[:filetypes] || []
    basenames = [basenames] unless basenames.is_a? Array
    filetypes = [filetypes] unless filetypes.is_a? Array
    do_unreg  = params[:commit] =~ /unregister/i
    do_erase  = params[:commit] =~ /delete/i

    # Automatic MOVE or COPY operation?
    move_or_copy = params[:auto_do]                || ""
    other_provid = params[:other_data_provider_id] || nil
    new_dp       = DataProvider.find_accessible_by_user(other_provid,current_user) rescue nil
    past_tense   = move_or_copy == "MOVE" ? "moved" : "copied"
    if (move_or_copy == "MOVE" || move_or_copy == "COPY") && !new_dp && !(do_unreg || do_erase)
      flash[:error] = "Error: you selected to automatically #{move_or_copy} your files but did not specify a destination Data Provider."
      redirect_to :action => :browse
      return
    end
    
    @fileinfolist = get_recent_provider_list_all(params[:refresh].presence, @as_user)

    base2info = {}
    @fileinfolist.each { |fi| base2info[fi.name] = fi }

    base2type = {}
    filetypes.select { |typebase| ! typebase.empty? }.each do |typebase|
      next unless typebase.match(/^(\w+)-(\S+)$/)
      type = $1
      base = $2
      base2type[base] = type
    end
    
    newly_registered_userfiles      = []
    previously_registered_userfiles = []
    num_unregistered = 0
    num_erased       = 0
    num_skipped      = 0

    flash[:error]  = ""
    flash[:notice] = ""

    legal_subtypes = Userfile.descendants.map(&:name).index_by { |x| x }

    registered_files = Userfile.where( :data_provider_id => @provider.id ).index_by(&:name)

    basenames.each do |basename|

      # Unregister files

      if do_unreg || do_erase
        userfile = Userfile.where(:name => basename, :data_provider_id => @provider.id).first
        if userfile.blank?
          num_skipped += 1 unless do_erase
        elsif ! userfile.has_owner_access?(current_user)
          flash[:error] += "Error: file #{basename} does not belong to you. File not unregistered.\n"
          num_skipped += 1
          next
        else
          num_unregistered += Userfile.delete(userfile.id) # NOT destroy()! We don't want to delete the content!
          userfile.destroy_log rescue true
        end
        next unless do_erase
      end

      # Erase unregistered files

      if do_erase
        fileinfo      = base2info[basename] rescue nil
        next unless fileinfo
        temp_class    = fileinfo.symbolic_type == :directory ? FileCollection : SingleFile
        temp_userfile = temp_class.new(
           :name          => basename,
           :data_provider => @provider,
           :user_id       => @as_user.id, # cannot use current_user, since it might be a vault_ssh dp
           :group_id      => current_user.own_group.id
        ).freeze # do not save this file! it's only used temporarily to delete the content on the DP
        erase_ok = @provider.provider_erase(temp_userfile) rescue nil
        if erase_ok
          num_erased += 1
        else
          num_skipped += 1
        end
        next
      end

      # Register new files

      subtype = "SingleFile"
      fileinfo = base2info[basename] rescue nil
      if base2type.has_key?(basename)
        subtype = base2type[basename]
        if subtype == "Unset" || ( ! legal_subtypes[subtype] )
          flash[:error] += "Error: entry #{basename} not provided with a proper type. File not registered.\n"
          num_skipped += 1
          next
        end
      end

      size = 0
      if SingleFile.valid_file_types.include?(subtype) # TODO what if it's a directory?
        size = fileinfo.size rescue 0
      end

      file_group_id   = params[:other_group_id].to_i unless params[:other_group_id].blank?
      file_group_id ||= current_session[:active_group_id] || current_user.own_group.id
      file_group_id   = current_user.own_group.id unless current_user.available_groups.map(&:id).include?(file_group_id)

      subclass = Class.const_get(subtype)
      userfile = subclass.new( :name             => basename, 
                               :size             => size,
                               :user_id          => @as_user.id, # cannot use current_user, since it might be a vault_ssh dp
                               :group_id         => file_group_id,
                               :data_provider_id => @provider.id )
      
      registered_file = registered_files[basename]
      if registered_file
        previously_registered_userfiles << registered_file
      elsif userfile.save
        newly_registered_userfiles << userfile
        userfile.addlog("Registered on DataProvider '#{@provider.name}' as '#{userfile.name}'.")
      else
        flash[:error] += "Error: could not register #{subtype} '#{basename}'... maybe the file exists already?\n"
        num_skipped += 1
      end

    end # loop to register/unregister files

    if num_skipped > 0
      flash[:notice] += "Skipped #{num_skipped} files.\n"
    end

    if newly_registered_userfiles.size > 0
      flash[:notice] += "Registered #{newly_registered_userfiles.size} files.\n"
      if @as_user != current_user
        flash[:notice] += "Important note! Since you were browsing as user '#{@as_user.login}', the files were registered as belonging to that user instead of you!\n"
      end
    elsif num_erased > 0
      clear_browse_provider_local_cache_file(@as_user, @provider)
      flash[:notice] += "Erased #{num_erased} files.\n"
    elsif num_unregistered > 0
      flash[:notice] += "Unregistered #{num_unregistered} files.\n"
    else
      flash[:notice] += "No files affected.\n"
    end

    # Nothing else do to if no automatic operation required.
    if (move_or_copy != "MOVE" && move_or_copy != "COPY") || !new_dp || newly_registered_userfiles.size == 0
      if newly_registered_userfiles.size > 0
        CBRAIN.spawn_with_active_records(:admin, "Set Sizes After Register") do
          newly_registered_userfiles.each do |userfile|
            userfile.set_size! rescue true
          end
        end
      end
      respond_to do |format|
        format.html { redirect_to :action => :browse }
        format.xml { render :xml =>
                      { :notice => flash[:notice],
                        :error  => flash[:error],
                        :newly_registered_userfiles => newly_registered_userfiles,
                        :previously_registered_userfiles => previously_registered_userfiles,
                        :userfiles_in_transit => []
                      }
                   }
      end
      return
    end

    # Alright, we need to move or copy the files
    collisions = newly_registered_userfiles.select do |u|
      found = Userfile.where(:name => u.name, :user_id => current_user.id, :data_provider_id => new_dp.id).first
      found ? true : false
    end
    to_operate = newly_registered_userfiles - collisions

    if collisions.size > 0
      flash[:error] += "Could not #{move_or_copy.downcase} some files, as files with the same names already exist:\n" +
                         collisions.map(&:name).sort.join(", ")
    end

    if to_operate.size == 0
      flash[:error] += "No files are left to #{move_or_copy.downcase} !\n"
    else
      flash[:notice] += "Warning! #{to_operate.size} files are now being #{past_tense} in background.\n"
      CBRAIN.spawn_with_active_records(:admin, "#{move_or_copy} Registered Files") do
        errors = ""
        num_ok  = 0
        num_err = 0
        to_operate.each do |u|
          orig_name = u.name
          begin
            if move_or_copy == "MOVE"
              u.provider_move_to_otherprovider(new_dp)
              u.set_size!
            elsif move_or_copy == "COPY" # and no ELSE !
              new = u.provider_copy_to_otherprovider(new_dp)
              u.destroy rescue true # will simply unregister
              new.set_size!
            end
            num_ok += 1
          rescue => ex
            num_err += 1
            errors += "Error for file '#{orig_name}': #{ex.class}: #{ex.message}\n"
          end
        end # each file
        if num_ok > 0
          Message.send_message(current_user, 
                                :message_type   => 'notice', 
                                :header         => "#{num_ok} files #{past_tense} during registration.",
                                :variable_text  => ""
                                )
        end
        if num_err > 0
          Message.send_message(current_user, 
                                :message_type   => 'error', 
                                :header         => "#{num_err} files FAILED to be #{past_tense} during registration. See report below.",
                                :variable_text  => errors
                                )
        end
      end # spawn
    end # if move or copy

    respond_to do |format|
      format.html { redirect_to :action => :browse }
      format.xml { render :xml =>
                    { :notice => flash[:notice],
                      :error  => flash[:error],
                      :newly_registered_userfiles => newly_registered_userfiles,
                      :previously_registered_userfiles => previously_registered_userfiles,
                      :userfiles_in_transit => to_operate
                    }
                 }
    end

  end
  
  private

  def get_type_list #:nodoc:
    typelist = %w{ SshDataProvider } 
    if check_role(:admin) || check_role(:site_manager)
      typelist += %w{ 
                      EnCbrainSshDataProvider EnCbrainLocalDataProvider EnCbrainSmartDataProvider
                      CbrainSshDataProvider CbrainLocalDataProvider CbrainSmartDataProvider
                      VaultLocalDataProvider VaultSshDataProvider VaultSmartDataProvider
                      IncomingVaultSshDataProvider 
                      S3DataProvider
                    }
    end
    typelist
  end
  
  def get_ssh_public_keys #:nodoc:
    # Get SSH key for this BrainPortal
    portal_ssh_key = RemoteResource.current_resource.get_ssh_public_key
    portal_ssh_key = 'Unknown! Talk to sysadmin!' if portal_ssh_key.blank?
    keys = [ [ 'This CBRAIN Portal', portal_ssh_key ] ]
    # Get those of all other Bourreaux
    keys += Bourreau.find_all_accessible_by_user(current_user).map{ |b| ["Execution Server '#{b.name}'", b.ssh_public_key] }
    keys
  end

  def get_recent_provider_list_all(refresh = false, as_user = current_user) #:nodoc:

    refresh = false if refresh.blank? || refresh.to_s == 'false'

    # Check to see if we can simply reload the cached copy
    cache_file = browse_provider_local_cache_file(as_user, @provider)
    if ! refresh && File.exist?(cache_file) && File.mtime(cache_file) > 60.seconds.ago
       filelisttext = File.read(cache_file)
       fileinfolist = YAML::load(filelisttext)
       return fileinfolist
    end

    # Get info from provider
    fileinfolist = @provider.provider_list_all(as_user)

    # Write a new cached copy
    File.open(cache_file + ".tmp","w") do |fh|
       fh.write(YAML::dump(fileinfolist))
    end
    File.rename(cache_file + ".tmp",cache_file)  # crush it

    # Return it
    fileinfolist
  end

  def browse_provider_local_cache_file(user, provider) #:nodoc:
    cache_file = "/tmp/dp_cache_list_all_#{user.id}.#{provider.id}"
    cache_file
  end

  def clear_browse_provider_local_cache_file(user, provider) #:nodoc:
    cache_file = browse_provider_local_cache_file(user, provider)
    File.unlink(cache_file) rescue true
  end

end
