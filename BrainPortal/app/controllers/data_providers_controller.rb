
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
  before_filter :manager_role_required, :except  => [:index, :browse, :register]
   
  def index #:nodoc:
    @providers = DataProvider.find_all_accessible_by_user(current_user)
    @typelist = get_type_list
    @ssh_keys = get_ssh_public_keys
  end

  # GET /data_providers/1
  # GET /data_providers/1.xml
  def show  #:nodoc:
    data_provider_id = params[:id]
    @provider        = DataProvider.find(data_provider_id)

    raise "Provider not accessible by current user." unless @provider.can_be_accessed_by?(current_user)

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
    #@mode     = "update"

    unless @provider.has_owner_access?(current_user)
       flash[:error] = "You cannot edit a provider that you do not own."
       redirect_to :action => :index
       return
    end

    @users = current_user.available_users
    @groups = current_user.available_groups
    @typelist = get_type_list

    @ssh_keys = get_ssh_public_keys

    respond_to do |format|
      format.html { render :action => :edit }
      format.xml  { render :xml => @provider }
    end

  end

  def new #:nodoc:
    @user     = current_user
    @provider = DataProvider.new( :user_id   => @user.id,
                                  :group_id  => Group.find_by_name(@user.login).id,
                                  :online    => true,
                                  :read_only => false
                                )
    @users = current_user.available_users
    @groups = current_user.available_groups
      
    @typelist = get_type_list
    @ssh_keys = get_ssh_public_keys

    respond_to do |format|
      format.html { render :action => :new }
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

  
    if @provider.errors.empty?
      flash[:notice] = "Provider successfully created."
      
      respond_to do |format|
        format.html {redirect_to(data_providers_url)}
        format.js
      end
    else
      @typelist = get_type_list
      @ssh_keys = get_ssh_public_keys

      
      respond_to do |format|
        format.html { render :action => :new }
        format.js
      end
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
      #@mode = "update"
      @users = current_user.available_users
      @groups = current_user.available_groups
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
      format.html {redirect_to :action => :index}
      format.js
    end
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

    @fileinfolist.each do |fi|
      fi_name  = fi.name
      fi_size  = fi.size
      fi_type  = fi.symbolic_type
      fi_mtime = fi.mtime

      fi.userfile = nil
      fi.message  = ""
      fi.state_ok = false

      registered = Userfile.find(:first, :conditions => { :name => fi_name, :data_provider_id => @provider.id})
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

  end

  #Register a given file into the system.
  #The file's meta data will be saved as a Userfile resource.
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
  
  private 
  
  def get_type_list #:nodoc:
    typelist = %w{ SshDataProvider } 
    if check_role(:admin) || check_role(:site_manager)
      typelist += %w{ CbrainSshDataProvider CbrainLocalDataProvider CbrainSmartDataProvider
                    VaultLocalDataProvider VaultSshDataProvider VaultSmartDataProvider }
    end
    typelist
  end

  def get_ssh_public_keys #:nodoc:

    # Get SSH key for this BrainPortal
    home = CBRAIN::Rails_UserHome
    portal_ssh_key = `cat #{home}/.ssh/id_rsa.pub`.strip
    portal_ssh_key = 'Unknown! Talk to sysadmin!' if portal_ssh_key.blank?
    keys = [ [ 'This CBRAIN Portal', portal_ssh_key ] ]

    # Get SSH keys for each Bourreau
    Bourreau.all.each do |b|
      next unless b.can_be_accessed_by?(current_user)
      name = b.name
      ssh_key = "This Bourreau is DOWN!"
      if b.is_alive?
        info = b.info
        ssh_key = info.ssh_public_key
      end
      keys << [ "Bourreau '#{name}'", ssh_key ]
    end

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

end
