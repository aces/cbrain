
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
    @providers = DataProvider.find_all_accessible_by_user(current_user)
  end

  # GET /data_providers/1
  # GET /data_providers/1.xml
  def show  #:nodoc:
    @provider = DataProvider.find(params[:id])

    raise "Provider not accessible by current user." unless @provider.can_be_accessed_by?(current_user)

    @ssh_keys = get_ssh_public_keys

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @provider }
    end
  end
  
  def edit #:nodoc:
    @provider = DataProvider.find(params[:id])
    @user     = current_user
    #@mode     = "update"

    unless @provider.has_owner_access?(current_user)
       flash[:error] = "You cannot edit a provider that you do not own."
       redirect_to :action => :index
       return
    end

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
    @typelist = get_type_list
    @ssh_keys = get_ssh_public_keys

    respond_to do |format|
      format.html { render :action => :new }
      format.xml  { render :xml => @provider }
    end

  end

  def create #:nodoc:
    @user     = current_user
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
      redirect_to(data_providers_url)
      flash[:notice] = "Provider successfully created."
    else
      @typelist = get_type_list
      @ssh_keys = get_ssh_public_keys
       
      render :action => :new
      return
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
    @ssh_keys = get_ssh_public_keys

    if @provider.errors.empty?
      redirect_to(data_providers_url)
      flash[:notice] = "Provider successfully updated."
    else
      #@mode = "update"
      @ssh_keys = get_ssh_public_keys
      render :action => 'edit'
      return
    end

  rescue
    access_error(404)
  end

  def destroy #:nodoc:
    id        = params[:id]
    @user     = current_user
    @provider = DataProvider.find(id)

    unless @provider.userfiles.empty?
      flash[:error] = "You cannot remove a provider that has still files registered on it."
      redirect_to :action => :show, :id => id
      return
    end

    if @provider.has_owner_access?(current_user)
      @provider.destroy
      flash[:notice] = "Provider successfully deleted."
    else
      flash[:error] = "You cannot remove a provider that you do not own."
    end

    redirect_to :action => :index
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
      @rawlist = @provider.provider_list_all
    rescue => e
      flash[:error] = "Cannot get list of files: #{e.to_s}"
      redirect_to :action => :index
      return
    end

    @rawlist.each do |tuplet|
      tupname  = tuplet[0]
      tupsize  = tuplet[1]
      tuptype  = tuplet[2]
      tupmtime = tuplet[3]
      registered = Userfile.find(:first, :conditions => { :name => tupname, :data_provider_id => @provider.id})
      if registered
        tuplet << registered  #userfile
        if ((tuptype == :regular    && registered.is_a?(SingleFile)) ||
            (tuptype == :directory  && registered.is_a?(FileCollection)))
          tuplet << "" # message
        else
          tuplet << "Conflicting types!"
        end
      else
        tuplet << nil   # userfile is nil
        tuplet << nil   # message
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
        unless userfile = Userfile.find(:first, :conditions => { :name => basename, :data_provider_id => provider_id } )
          num_skipped += 1
          next
        end
        num_unregistered += Userfile.delete(userfile.id)
        next
      end

      # Register new files

      subtype = "SingleFile"
      if base2type.has_key?(basename)
        subtype = base2type[basename]
        if subtype == "Unset" || (subtype != "FileCollection" && subtype != "CivetCollection")
           flash[:error] += "Error: subdirectory #{basename} not provided with a proper type. File not registered.\n"
           num_skipped += 1
           next
        end
      end

      subclass = Class.const_get(subtype)
      userfile = subclass.new( :name             => basename, 
                               :size             => 0,
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
    if check_role(:admin) 
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

end
