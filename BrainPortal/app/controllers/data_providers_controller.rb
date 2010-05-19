
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
   
  def index #:nodoc:
    @providers = DataProvider.find_all_accessible_by_user(current_user).group_by{ |dp| dp.is_browsable? ? "User Storage" : "CBRAIN Official Storage" }
    @providers["CBRAIN Official Storage"] ||= []
    @providers["User Storage"] ||= []
    @typelist = get_type_list
    @ssh_keys = get_ssh_public_keys
  end

  # GET /data_providers/1
  # GET /data_providers/1.xml
  def show  #:nodoc:
    data_provider_id = params[:id]
    @provider        = DataProvider.find(data_provider_id)

    cb_notice "Provider not accessible by current user." unless @provider.can_be_accessed_by?(current_user)

    @ssh_keys = get_ssh_public_keys

    # Gather statistics
    @user_sf_fc = {}
    users = current_user.available_users
    
    users.each do |user|
      user_id = user.id
      login   = user.login
      userfiles = Userfile.find(:all, :conditions => { :data_provider_id => data_provider_id, :user_id => user_id })
      sf = fc = 0
      userfiles.each { |u| sf += 1 if u.is_a?(SingleFile) }
      userfiles.each { |u| fc += 1 if u.is_a?(FileCollection) }
      @user_sf_fc[login] = [ sf, fc ]
    end

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
    
    if errors.empty?
      @provider.save
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
    @provider  = DataProvider.find(id)
    @destroyed = false

    unless @provider.userfiles.empty?
      flash[:error] = "You cannot remove a provider that has still files registered on it."
      respond_to do |format|
        format.html {redirect_to :action => :show, :id => id}
        format.js
      end
      return
    end

    if @provider.has_owner_access?(current_user)
      @provider.destroy
      @destroyed = true
      flash[:notice] = "Provider successfully deleted."
    else
      flash[:error] = "You cannot remove a provider that you do not own."
    end

    respond_to do |format|
      format.html {redirect_to :action  => :index}
      format.js
    end
  end
  
  def is_alive
    @provider = DataProvider.find_accessible_by_user(params[:id], current_user)
    if @provider.is_alive?
      render :text  => "Yes"
    else
      render :text  => "<font color=\"red\">No</font>"
    end
    return
  end
  
  def disk_usage
    @providers = DataProvider.find_all_accessible_by_user(current_user)

    # List of cache update offsets we support
    @offset_times = [
      [ "Anytime",           0.seconds.to_i ],
      [ "One hour ago",      1.hour.to_i    ],
      [ "Six hours ago",     6.hour.to_i    ],
      [ "One day ago",       6.day.to_i     ],
      [ "One week ago",      1.week.to_i    ],
      [ "Two weeks ago",     2.week.to_i    ],
      [ "One month ago",     1.month.to_i   ],
      [ "Two months ago",    2.months.to_i  ],
      [ "Three months ago",  3.months.to_i  ],
      [ "Four months ago",   4.months.to_i  ],
      [ "Six months ago",    6.months.to_i  ],
      [ "Nine months ago",   9.months.to_i  ],
      [ "Over one year ago", 1.year.to_i    ]
    ]

    # Restrict cache info stats to files 'older' than
    # a certain number of seconds (by access time).
    accessed_before = nil
    accessed_after  = nil # not used right now
    @cache_older     = params[:cache_older] || 0
    if @cache_older.to_s =~ /^\d+/
      @cache_older = @cache_older.to_i
      @offset_times.reverse_each do |pair|
        if @cache_older >= pair[1]
          @cache_older = pair[1]
          break
        end
      end
      accessed_before = @cache_older.seconds.ago # this is a Time
    else
      @cache_older = 0
    end

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

    # Create statistics table
    stats_options = { :users            => userlist,
                      :providers        => @providers,
                      :remote_resources => rrlist,
                      :accessed_before  => accessed_before
                    }
    @report_stats    = gather_usage_statistics(stats_options)

    # Keys and arrays into statistics tables, for HTML output
    @report_col_objects = @report_stats['!col_objects!']  # DPs+   + 'all'? + RRs+
    @report_row_objects = @report_stats['!row_objects!']  # users+ + 'all'?
    @report_dps         = @report_stats['!dps!'] # does not include the 'all' column, if any
    @report_rrs         = @report_stats['!rrs!']
    @report_users       = @report_stats['!users!'] # does not include the 'all' column, if any
    
    render :partial  => "disk_usage"
  end

  #Browse the files of a data provider.
  #This action is only available for data providers that are browsable.
  #Both registered and unregistered files will appear in the list. 
  #Unregistered files can be registered here.
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
      flash[:error] = "Cannot get list of files: #{e.to_s}"
      redirect_to :action => :index
      return
    end

    # Let's add three more custom attributes:
    # - the userfile if the file is already registered
    # - the state_ok flag that tell whether or not it's OK to register/deregister
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
      params[:page] = 1
      @fileinfolist = @fileinfolist.select{|file| file.name =~ /#{params[:search]}/}
    end

    page = (params[:page] || 1).to_i
    @per_page = params[:pagination] == "on" ? 50 : 999_999_999

    @fileinfolist = WillPaginate::Collection.create(page, @per_page) do |pager|
      pager.replace(@fileinfolist[(page-1) * @per_page, @per_page])
      pager.total_entries = @fileinfolist.size
      pager
    end
    
    respond_to do |format|
      format.html
      format.js do
        render :update do |page|
          page[:browse_table].replace_html :partial  => "dp_browse_table"
        end
      end
    end

  end

  #Register a given file into the system.
  #The file's meta data will be saved as a Userfile resource.
  def register
    unless params[:redirect_to_browse].blank?
      params[:action] = :browse
      redirect_to :action => :browse, :search  => params[:search], :pagination  => params[:pagination]
      return
    end
    
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
    dirtypes  = params[:directorytypes] || []
    do_unreg  = params[:commit] =~ /unregister/i

    @fileinfolist = get_recent_provider_list_all(params[:refresh])

    base2info = {}
    @fileinfolist.each { |fi| base2info[fi.name] = fi }

    base2type = {}
    dirtypes.select { |typebase| ! typebase.empty? }.each do |typebase|
      next unless typebase.match(/^(\w+)-(\S+)$/)
      type = $1
      base = $2
      base2type[base] = type
    end
    
    num_registered   = 0
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
        num_unregistered += Userfile.delete(userfile.id)
        userfile.destroy_log rescue true
        next
      end

      # Register new files

      subtype = "SingleFile"
      fileinfo = base2info[basename] rescue nil
      if base2type.has_key?(basename)
        subtype = base2type[basename]
        if subtype == "Unset" || (subtype != "SingleFile" && subtype != "FileCollection" && subtype != "CivetCollection")
          flash[:error] += "Error: entry #{basename} not provided with a proper type. File not registered.\n"
          num_skipped += 1
          next
        end
      end

      size = 0
      if subtype == "SingleFile" # TODO what if it's a directory?
        size = fileinfo.size rescue 0
      end

      subclass = Class.const_get(subtype)
      userfile = subclass.new( :name             => basename, 
                               :size             => size,
                               :user_id          => user_id,
                               :group_id         => @provider.group_id,
                               :data_provider_id => provider_id )
      if userfile.save
        CBRAIN.spawn_with_active_records_unless(userfile.size_set?, current_user,"FileCollection Set Size") do
          userfile.set_size!
        end
        num_registered += 1
      else
        flash[:error] += "Error: could not register #{subtype} '#{basename}'\n"
        num_skipped += 1
      end

    end

    if num_skipped > 0
      flash[:notice] += "Skipped #{num_skipped} files.\n"
    end

    if num_registered > 0
      flash[:notice] += "Registered #{num_registered} files.\n"
    elsif num_unregistered > 0
      flash[:notice] += "Unregistered #{num_unregistered} files.\n"
    else
      flash[:notice] += "No files affected.\n"
    end

    redirect_to :action => :browse
    
  end


  # Provides the interface to trigger cache cleanup operations
  def cleanup
    flash[:notice] ||= ""

    # First param is cleanup_before, which is the number
    # of second before NOW at which point files become
    # eligible for elimination
    cleanup_before = params[:cleanup_before] || 0
    if cleanup_before.to_s =~ /^\d+/
      cleanup_before = cleanup_before.to_i
      cleanup_before = 1.year.to_i if cleanup_before > 1.year.to_i
    else
      cleanup_before = 0
    end

    # Second param is clean_cache, a set of pairs in
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
        remote_resource.send_command_clean_cache(userids,cleanup_before.ago)
        flash[:notice] += "Sending cleanup command to #{remote_resource.name}."
      rescue => e
        flash[:notice] += "Could not contact #{remote_resource.name}."
      end
    end

    redirect_to :action => :disk_usage, :cache_older => cleanup_before
  end
  
  private 
  
  def get_type_list #:nodoc:
    typelist = %w{ SshDataProvider } 
    if check_role(:admin) || check_role(:site_manager)
      typelist += %w{ 
                      EnCbrainSshDataProvider EnCbrainLocalDataProvider EnCbrainSmartDataProvider
                      CbrainSshDataProvider CbrainLocalDataProvider CbrainSmartDataProvider
                      VaultLocalDataProvider VaultSshDataProvider VaultSmartDataProvider
                    }
    end
    typelist
  end

  def get_ssh_public_keys #:nodoc:

    # Get SSH key for this BrainPortal
    home = CBRAIN::Rails_UserHome
    portal_ssh_key = `cat #{home}/.ssh/id_rsa.pub`.strip
    portal_ssh_key = 'Unknown! Talk to sysadmin!' if portal_ssh_key.blank?
    keys = [ [ 'This CBRAIN Portal', portal_ssh_key ] ]
    keys += Bourreau.all.map{ |b| ["Execution Server '#{b.name}'", b.ssh_public_key] }
    # Get SSH keys for each Bourreau
    # Bourreau.all.each do |b|
    #   next unless b.can_be_accessed_by?(current_user)
    #   name = b.name
    #   ssh_key = "This Execution Server is DOWN!"
    #   if b.is_alive?
    #     info = b.info
    #     ssh_key = info.ssh_public_key
    #   end
    #   keys << [ "Execution Server '#{name}'", ssh_key ]
    # end

    keys
  end

  def get_recent_provider_list_all(refresh = false)

    refresh = false if refresh.blank? || refresh.to_s == 'false'

    # Check to see if we can simply reload the cached copy
    cache_file = "/tmp/dp_cache_list_all.#{@provider.id}"
    if ! refresh && File.exist?(cache_file) && File.mtime(cache_file) > 60.seconds.ago
       filelisttext = File.read(cache_file)
       fileinfolist = YAML::load(filelisttext)
       return fileinfolist
    end

    # Get info from provider
    fileinfolist = @provider.provider_list_all

    # Write a new cached copy
    File.open(cache_file + ".tmp","w") do |fh|
       fh.write(YAML::dump(fileinfolist))
    end
    File.rename(cache_file + ".tmp",cache_file)  # crush it

    # Return it
    fileinfolist
  end

  # Creates and returns a table with statistics for disk usage on a
  # set of Data Providers and Remote Resource caches.
  #
  # The +options+ arguments can restrict the domain of the statistics
  # gathered:
  #
  #   * :users            => [ user, user...]
  #   * :providers        => [ dp, dp...]
  #   * :remote_resources => [ rr, rr...]
  #   * :accessed_before  => Time
  #   * :accessed_after   => Time
  #
  # The accessed_* options apply to the cached userfiles
  # on the remote_resources, and are compared to the
  # :accessed_at attribute of the SyncStatus structure.
  def gather_usage_statistics(options)

    users            = options[:users]
    providers        = options[:providers]
    remote_resources = options[:remote_resources]
    accessed_before  = options[:accessed_before]
    accessed_after   = options[:accessed_after]

    # Internal constants
    all_users_label  = 'All Users'     # used as a key in the table's hash
    all_dps_label    = 'All Providers' # used as a key in the table's hash

    # Which users to gather stats for
    userlist = if users
                 users.is_a?(Array) ? users : [ users ]
               else
                 User.all
               end

    # Which data providers to gather stats for
    dplist   = if providers
                 providers.is_a?(Array) ? providers : [ providers ]
               else
                 DataProvider.all
               end

    # Which remote resource to gather stats for
    rrlist   = if remote_resources
                 remote_resources.is_a?(Array) ? remote_resources : [ remote_resources ]
               else
                 RemoteResource.all
               end

    # All files that belong to these users on these data providers
    if users.nil? && providers.nil?
      filelist = Userfile.find(:all)
    elsif users.nil?
      filelist = Userfile.find(:all, :conditions => { :data_provider_id => dplist })
    elsif providers.nil?
      filelist = Userfile.find(:all, :conditions => { :user_id => userlist })
    else
      filelist = Userfile.find(:all, :conditions => { :user_id => userlist, :data_provider_id => dplist })
    end

    # Arrays and hashes used to record the names of the
    # rows and columns of the report
    users_index = userlist.index_by &:id
    dp_index    = dplist.index_by   &:id
    rr_index    = rrlist.index_by   &:id

    # Stats structure. It represents a two-dimensional table
    # where rows are users and columns are data providers.
    # And extra row called 'All Users' sums up the stats for all users
    # on a data provider, and an extra row called 'All Providers' sums up
    # the stats for one users on all data providers.
    stats = { all_users_label => {} }

    tt_cell = stats[all_users_label][all_dps_label] = { :size => 0, :num_entries => 0, :num_files => 0, :unknowns => 0 }

    filelist.each do |userfile|
      filetype          = userfile.class.to_s
      size              = userfile.size
      num_files         = userfile.num_files || 1

      user_id           = userfile.user_id
      user              = users_index[user_id]

      data_provider_id  = userfile.data_provider_id
      dp                = dp_index[data_provider_id]

      # up_cell is normal cell for one user on one dp
      # tp_cell is total cell for all users on one dp
      # ut_cell is total cell for on user on all dps
                stats[user]                ||= {} # row init
      up_cell = stats[user][dp]            ||= { :size => 0, :num_entries => 0, :num_files => 0, :unknowns => 0 }
      tp_cell = stats[all_users_label][dp] ||= { :size => 0, :num_entries => 0, :num_files => 0, :unknowns => 0 }
      ut_cell = stats[user][all_dps_label] ||= { :size => 0, :num_entries => 0, :num_files => 0, :unknowns => 0 }

      cells = [ up_cell, tp_cell, ut_cell, tt_cell ]

      # Gather information from caches on remote_resources
      synclist = userfile.sync_status
      synclist.each do |syncstat| # we assume ALL status keywords mean there is some content in the cache

        # Only syncstats on the remote_resources we want to look at
        rr_id   = syncstat.remote_resource_id
        rr      = rr_index[rr_id]
        next unless rr

        # Only syncstats with proper access time
        accessed_at = syncstat.accessed_at
        next if accessed_before && accessed_at > accessed_before
        next if accessed_after  && accessed_at < accessed_after

        # rr_cell is normal cell for one user on one remote resource
        # tr_cell is total cell for all users on one remote resource
        rr_cell = stats[user][rr]            ||= { :size => 0, :num_entries => 0, :num_files => 0, :unknowns => 0 }
        tr_cell = stats[all_users_label][rr] ||= { :size => 0, :num_entries => 0, :num_files => 0, :unknowns => 0 }
        cells << rr_cell
        cells << tr_cell
      end

      # Update counts for all cells
      cells.each do |cell|
        if size
          cell[:size]        += size
          cell[:num_entries] += 1
          cell[:num_files]   += num_files
        else
          cell[:unknowns] += 1
        end
      end
    end

    dps_final   =    dp_index.values.sort { |a,b| a.name  <=> b.name  }
    rrs_final   =    rr_index.values.sort { |a,b| a.name  <=> b.name  }
    users_final = users_index.values.sort { |a,b| a.login <=> b.login }

    stats['!col_objects!']  = dps_final
    stats['!col_objects!'] += [ all_dps_label ] if dps_final.size > 1
    stats['!col_objects!'] += rrs_final

    stats['!row_objects!']  = users_final
    stats['!row_objects!'] += [ all_users_label ] if users_final.size > 1

    stats['!dps!']      = dps_final
    stats['!rrs!']      = rrs_final
    stats['!users!']    = users_final

    # These two entries are provided so that
    # the presentation layer can tell which entries
    # are the special summation columns
    stats['!all_users_label!'] = all_users_label
    stats['!all_dps_label!']   = all_dps_label

    stats
  end

end
