
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

  Revision_info="$Id$"

  before_filter :login_required
  before_filter :manager_role_required, :only  => [:new, :create]
   
  def index #:nodoc:
    @all_providers = DataProvider.find_all_accessible_by_user(current_user)
    @providers = @all_providers.group_by{ |dp| dp.is_browsable? ? "User Storage" : "CBRAIN Official Storage" }
    @providers["CBRAIN Official Storage"] ||= []
    @providers["User Storage"] ||= []
    @typelist = get_type_list
    @ssh_keys = get_ssh_public_keys
    
    #For new form
    provider_group_id = ( current_project && current_project.id ) || current_user.own_group.id
    @provider = DataProvider.new( :user_id   => current_user.id,
                                  :group_id  => provider_group_id,
                                  :online    => true,
                                  :read_only => false
                                )
    respond_to do |format|
      format.html
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

    stats = ApplicationController.helpers.gather_filetype_statistics(
              :users     => current_user.available_users,
              :providers => @provider
            )
    @user_fileclass_count = stats[:user_fileclass_count]
    @fileclasses_totcount = stats[:fileclasses_totcount]
    @user_totcount        = stats[:user_totcount]

    # List of acceptable users
    userlist         = if check_role(:admin)
                         User.all
                       elsif check_role(:site_manager)
                         current_user.site.users
                       else
                         [ current_user ]
                       end

    # Create disk usage statistics table
    stats_options = { :users            => userlist,
                      :providers        => [ @provider ],
                      :remote_resources => [],
                    }
    @report_stats    = ApplicationController.helpers.gather_dp_usage_statistics(stats_options)

    # Keys and arrays into statistics tables, for HTML output
    @report_dps         = @report_stats['!dps!'] # does not include the 'all' column, if any
    @report_rrs         = @report_stats['!rrs!']
    @report_users       = @report_stats['!users!'] # does not include the 'all' column, if any
    @report_dps_all     = @report_stats['!dps+all?!']      # DPs   + 'all'?
    @report_users_all   = @report_stats['!users+all?!']    # users + 'all'?
    
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @provider }
    end
  end
  
  def edit #:nodoc:
    @provider = DataProvider.find(params[:id])

    unless @provider.has_owner_access?(current_user)
       flash[:error] = "You cannot edit a provider that you do not own."
       redirect_to :action => :index
       return
    end

    @typelist = get_type_list

    @ssh_keys = get_ssh_public_keys

    respond_to do |format|
      format.html { render :action => :edit }
      format.xml  { render :xml => @provider }
    end

  end

  def create #:nodoc:
    fields    = params[:data_provider]
    subtype   = fields.delete(:type)

    errors = {}
  
    if subtype.empty?
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
      add_meta_data_from_form(@provider, [:must_move, :no_uploads])
    else
      errors.each do |attr, msg|
        @provider.errors.add(attr, msg)
      end
    end
    
    @typelist = get_type_list
    @ssh_keys = get_ssh_public_keys

  
    if @provider.errors.empty?
      flash[:notice] = "Provider successfully created."
    end 
    
    respond_to do |format|
      format.js 
    end
  end

  def update #:nodoc:

    @user     = current_user
    id        = params[:id]
    @provider = DataProvider.find(id)

    unless @provider.has_owner_access?(current_user)
       flash[:error] = "You cannot edit a provider that you do not own."
       redirect_to :action => :index
       return
    end

    fields    = params[:data_provider]
    subtype   = fields.delete(:type)

    @provider.update_attributes(fields)

    if @provider.errors.empty?
      add_meta_data_from_form(@provider, [:must_move, :no_uploads])
      redirect_to(data_providers_url)
      flash[:notice] = "Provider successfully updated."
    else
      @ssh_keys = get_ssh_public_keys
      @typelist = get_type_list
      render :action => 'edit'
      return
    end
  end

  def destroy #:nodoc:
    id         = params[:id]
    @user      = current_user
    @data_provider  = DataProvider.find(id)

    unless @data_provider.userfiles.empty?
      flash[:error] = "You cannot remove a provider that still has files registered on it."
      @data_provider.errors.add(:base, "You cannot remove a provider that still has files registered on it.")
      respond_to do |format|
        format.html {redirect_to :action => :show, :id => id}
        format.js {render :partial  => 'shared/destroy', :locals  => {:model_name  => 'data_provider' }}
      end
      return
    end

    if @data_provider.has_owner_access?(current_user)
      @data_provider.destroy
      flash[:notice] = "Provider successfully deleted."
    else
      flash[:error] = "You cannot remove a provider that you do not own."
    end

    respond_to do |format|
      format.html {redirect_to :action  => :index}
      format.js {render :partial  => 'shared/destroy', :locals  => {:model_name  => 'data_provider' }}
    end
  end
  
  def is_alive #:nodoc:
    @provider = DataProvider.find_accessible_by_user(params[:id], current_user)        
    render :text  => red_if( ! @provider.is_alive?, "Yes", "No" )
  end
  
  def disk_usage #:nodoc:
    @providers = DataProvider.find_all_accessible_by_user(current_user)

    # List of cache update offsets we support
    big_bang = 50.years.to_i # for convenience, because obviously 13.75 billion != 50 !
    @offset_times = [
      [ "Now",               0.seconds.to_i ],
      [ "One hour ago",      1.hour.to_i    ],
      [ "Six hours ago",     6.hour.to_i    ],
      [ "One day ago",       1.day.to_i     ],
      [ "One week ago",      1.week.to_i    ],
      [ "Two weeks ago",     2.week.to_i    ],
      [ "One month ago",     1.month.to_i   ],
      [ "Two months ago",    2.months.to_i  ],
      [ "Three months ago",  3.months.to_i  ],
      [ "Four months ago",   4.months.to_i  ],
      [ "Six months ago",    6.months.to_i  ],
      [ "Nine months ago",   9.months.to_i  ],
      [ "One year ago",      1.year.to_i    ],
      [ "The Big Bang",      big_bang       ]
    ]
   

    # Restrict cache info stats to files within
    # a certain range of oldness.
    accessed_before = nil
    accessed_after  = nil

    # 0 sec ago ................. < ..................... infinite secs ago
    # now .......... older_limit .... younger_limit ..... long ago
    #                 acc_after   <     acc_before

    @cache_older   = params[:cache_older]   || 0.seconds.to_i
    @cache_younger = params[:cache_younger] || big_bang
    @cache_older   = @cache_older.to_s   =~ /^\d+/ ? @cache_older.to_i   : 0
    @cache_younger = @cache_younger.to_s =~ /^\d+/ ? @cache_younger.to_i : big_bang
    @cache_older   = big_bang if @cache_older   > big_bang
    @cache_younger = big_bang if @cache_younger > big_bang
    if (@cache_younger < @cache_older) # the interface allows the user to reverse them
      @cache_younger, @cache_older = @cache_older, @cache_younger
    end

    @offset_times.reverse_each do |pair|
      if @cache_older >= pair[1]
        @cache_older   = pair[1]
        break
      end
    end

    @offset_times.each do |pair|
      if @cache_younger <= pair[1]
        @cache_younger   = pair[1]
        break
      end
    end

    accessed_before = @cache_older.seconds.ago # this is a Time
    accessed_after  = @cache_younger.seconds.ago # this is a Time

    # Users in statistics table
    userlist         = if check_role(:admin)
                         User.all
                       elsif check_role(:site_manager)
                         current_user.site.users
                       else
                         [ current_user ]
                       end

    # Remote resources in statistics table
    rrlist           = RemoteResource.find_all_accessible_by_user(current_user)

    # Create disk usage statistics table
    stats_options = { :users            => userlist,
                      :providers        => @providers,
                      :remote_resources => rrlist,
                      :accessed_before  => accessed_before,
                      :accessed_after   => accessed_after
                    }
    @report_stats    = ApplicationController.helpers.gather_dp_usage_statistics(stats_options)

    # Keys and arrays into statistics tables, for HTML output
    @report_dps         = @report_stats['!dps!'] # does not include the 'all' column, if any
    @report_rrs         = @report_stats['!rrs!']
    @report_users       = @report_stats['!users!'] # does not include the 'all' column, if any
    @report_dps_all     = @report_stats['!dps+all?!']      # DPs   + 'all'?
    @report_users_all   = @report_stats['!users+all?!']    # users + 'all'?
    
    render :partial  => "disk_usage"
  end

  #Browse the files of a data provider.
  #This action is only available for data providers that are browsable.
  #Both registered and unregistered files will appear in the list. 
  def browse
    @user     = current_user
    id        = params[:id]
    @provider = DataProvider.find(id)

    unless @provider.can_be_accessed_by?(@user) && @provider.is_browsable?
      flash[:error] = "You cannot browse this provider."
      redirect_to :action => :index
      return
    end

    begin
      # [ base, size, type, mtime ]
      @fileinfolist = get_recent_provider_list_all(params[:refresh])
    rescue => e
      flash[:error] = 'Cannot get list of files. Maybe the remote directory doesn\'t exist or is locked?' #emacs fails to parse this properly so I switched to single quotes. 

      redirect_to :action => :index
      return
    end

    # Let's add three more custom attributes:
    # - the userfile if the file is already registered
    # - the state_ok flag that tell whether or not it's OK to register/unregister
    # - a message.
    if @fileinfolist.size > 0
       @fileinfolist[0].class.class_eval("attr_accessor :userfile, :state_ok, :message")
    end

    registered_files = Userfile.find(:all, :conditions => {:data_provider_id => @provider.id}).index_by(&:name)

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

    if params[:search]
      search_term = params[:search].to_s.downcase
      params[:page] = 1
      @fileinfolist = @fileinfolist.select{|file| file.name.to_s.downcase.index(search_term)}
    end

    page = (params[:page] || 1).to_i
    params[:pagination] ||= "on"
    @per_page = params[:pagination] == "on" ? 50 : 999_999_999

    @fileinfolist = WillPaginate::Collection.create(page, @per_page) do |pager|
      pager.replace(@fileinfolist[(page-1) * @per_page, @per_page])
      pager.total_entries = @fileinfolist.size
      pager
    end
    
    respond_to do |format|
      format.html
      format.js
    end

  end

  #Register a list of files into the system.
  #The files' meta data will be saved as Userfile resources.
  def register
    @user        = current_user
    user_id      = @user.id
    provider_id  = params[:id]
    @provider    = DataProvider.find(provider_id)

    unless @provider.can_be_accessed_by?(@user) && @provider.is_browsable?
      flash[:error] = "You cannot register files from this provider."
      redirect_to :action => :index
      return
    end

    basenames = params[:basenames] || []
    filetypes  = params[:filetypes] || []
    do_unreg  = params[:commit] =~ /unregister/i

    # Automatic MOVE or COPY operation?
    move_or_copy = params[:auto_do]                || ""
    other_provid = params[:other_data_provider_id] || nil
    new_dp       = DataProvider.find_accessible_by_user(other_provid,current_user) rescue nil
    past_tense   = move_or_copy == "MOVE" ? "moved" : "copied"
    if (move_or_copy == "MOVE" || move_or_copy == "COPY") && !new_dp && !do_unreg
      flash[:error] = "Error: you selected to automatically #{move_or_copy} your files but did not specify a destination Data Provider."
      redirect_to :action => :browse
      return
    end
    
    @fileinfolist = get_recent_provider_list_all(params[:refresh])

    base2info = {}
    @fileinfolist.each { |fi| base2info[fi.name] = fi }

    base2type = {}
    filetypes.select { |typebase| ! typebase.empty? }.each do |typebase|
      next unless typebase.match(/^(\w+)-(\S+)$/)
      type = $1
      base = $2
      base2type[base] = type
    end
    
    newly_registered_userfiles = []
    num_unregistered = 0
    num_skipped      = 0

    flash[:error]  = ""
    flash[:notice] = ""

    basenames.each do |basename|

      # Unregister old files

      if do_unreg
        userfile = Userfile.find(:first, :conditions => { :name => basename, :data_provider_id => provider_id } )
        unless userfile
          num_skipped += 1
          next
        end
        unless userfile.has_owner_access?(current_user)
          flash[:error] += "Error: file #{basename} does not belong to you. File not unregistered.\n"
          num_skipped += 1
          next
        end
        num_unregistered += Userfile.delete(userfile.id) # NOT destroy()! We don't want to delete the content!
        userfile.destroy_log rescue true
        next
      end

      # Register new files

      subtype = "SingleFile"
      fileinfo = base2info[basename] rescue nil
      if base2type.has_key?(basename)
        subtype = base2type[basename]
        if subtype == "Unset" || (!Userfile.send(:subclasses).map(&:name).include?(subtype))
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
                               :user_id          => user_id,
                               :group_id         => file_group_id,
                               :data_provider_id => provider_id )
      if userfile.save
        newly_registered_userfiles << userfile
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
    elsif num_unregistered > 0
      flash[:notice] += "Unregistered #{num_unregistered} files.\n"
    else
      flash[:notice] += "No files affected.\n"
    end

    # Nothing else do to if no automatic operation required.
    if (move_or_copy != "MOVE" && move_or_copy != "COPY") || !new_dp || newly_registered_userfiles.size == 0
      if newly_registered_userfiles.size > 0
        CBRAIN.spawn_with_active_records("Set Sizes After Register") do
          newly_registered_userfiles.each do |userfile|
            userfile.set_size! rescue true
          end
        end
      end
      redirect_to :action => :browse
      return
    end

    # Alright, we need to move or copy the files
    collisions = newly_registered_userfiles.select do |u|
      found = Userfile.find(:first, :conditions => { :name => u.name, :user_id => current_user.id, :data_provider_id => new_dp.id })
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
      CBRAIN.spawn_with_active_records("#{move_or_copy} Registered Files") do
        errors = ""
        num_ok  = 0
        num_err = 0
        to_operate.each do |u|
          orig_name = u.name
          begin
            if move_or_copy == "MOVE"
              u.provider_move_to_otherprovider(new_dp)
              u.set_size!
            elsif move_or_copy == "COPY" # an no ELSE !
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
                                :header         => "#{num_ok} files FAILED to be #{past_tense} during registration. See report below.",
                                :variable_text  => errors
                                )
        end
      end # spawn
    end # if move or copy

    redirect_to :action => :browse

  end


  # Provides the interface to trigger cache cleanup operations
  def cleanup
    flash[:notice] ||= ""

    # First param is cleanup_older, which is the number
    # of second before NOW at which point files OLDER than
    # that become eligible for elimination
    cleanup_older = params[:cleanup_older] || 0
    if cleanup_older.to_s =~ /^\d+/
      cleanup_older = cleanup_older.to_i
      cleanup_older = 1.year.to_i if cleanup_older > 1.year.to_i
    else
      cleanup_older = 1.year.to_i
    end

    # Second param is cleanup_younger, which is the number
    # of second before NOW at which point files YOUNGER than
    # that become eligible for elimination
    cleanup_younger = params[:cleanup_younger] || 0
    if cleanup_younger.to_s =~ /^\d+/
      cleanup_younger = cleanup_younger.to_i
      cleanup_younger = 1.year.to_i if cleanup_younger > 1.year.to_i
    else
      cleanup_younger = 0
    end

    # Third param is clean_cache, a set of pairs in
    # the form "uuu,rrr" where uuu is a user_id and
    # rrr is a remote_resource_id. Both must be accessible
    # by the current user.
    clean_cache    = params[:clean_cache]    || []
    unless clean_cache.is_a?(Array)
      clean_cache = [ clean_cache ]
    end

    # List of acceptable users
    userlist         = if check_role(:admin)
                         User.all
                       elsif check_role(:site_manager)
                         current_user.site.users
                       else
                         [ current_user ]
                       end

    # List of acceptable remote_resources
    rrlist           = RemoteResource.find_all_accessible_by_user(current_user)

    # Index of acceptable users and remote_resources
    userlist_index   = userlist.index_by &:id
    rrlist_index     = rrlist.index_by &:id

    # Extract what caches are asked to be cleaned up
    rrid_to_userids = {}  # rr_id => { uid => true , uid => true , uid => true ...}
    clean_cache.each do |pair|
      next unless pair.to_s.match(/^(\d+),(\d+)$/)
      user_id            = Regexp.last_match[1].to_i
      remote_resource_id = Regexp.last_match[2].to_i
      # Make sure we're allowed
      next unless userlist_index[user_id] && rrlist_index[remote_resource_id]
      # Group and uniq them
      rrid_to_userids[remote_resource_id] ||= {}
      rrid_to_userids[remote_resource_id][user_id] = true
    end

    # Send the cleanup message
    rrid_to_userids.each_key do |rrid|
      remote_resource = RemoteResource.find(rrid)
      userlist = rrid_to_userids[rrid]  # uid => true, uid => true ...
      userids = userlist.keys.each { |uid| uid.to_s }.join(",")  # "uid,uid,uid"
      flash[:notice] += "\n" unless flash[:notice].blank?
      begin
        remote_resource.send_command_clean_cache(userids,cleanup_older.ago,cleanup_younger.ago)
        flash[:notice] += "Sending cleanup command to #{remote_resource.name}."
      rescue => e
        flash[:notice] += "Could not contact #{remote_resource.name}."
      end
    end

    redirect_to :action => :disk_usage, :cache_older => cleanup_older, :cache_younger => cleanup_younger
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
                    }
    end
    typelist
  end

  def get_ssh_public_keys #:nodoc:
    # Get SSH key for this BrainPortal
    home = CBRAIN::Rails_UserHome
    portal_ssh_key = (File.read("#{home}/.ssh/id_rsa.pub") rescue "").strip
    portal_ssh_key = 'Unknown! Talk to sysadmin!' if portal_ssh_key.blank?
    keys = [ [ 'This CBRAIN Portal', portal_ssh_key ] ]
    # Get those of all other Bourreaux
    keys += Bourreau.all.map{ |b| ["Execution Server '#{b.name}'", b.ssh_public_key] }
    keys
  end

  def get_recent_provider_list_all(refresh = false) #:nodoc:

    refresh = false if refresh.blank? || refresh.to_s == 'false'

    # Check to see if we can simply reload the cached copy
    cache_file = browse_provider_local_cache_file(current_user, @provider)
    if ! refresh && File.exist?(cache_file) && File.mtime(cache_file) > 60.seconds.ago
       filelisttext = File.read(cache_file)
       fileinfolist = YAML::load(filelisttext)
       return fileinfolist
    end

    # Get info from provider
    fileinfolist = @provider.provider_list_all(current_user)

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
    cache_file = browse_provider_local_cache_file(user,provider)
    File.unkink(cache_file) rescue true
  end

end
