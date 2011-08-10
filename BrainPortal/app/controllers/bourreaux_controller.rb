
#
# CBRAIN Project
#
# Bourreau controller for the BrainPortal interface
#
# Original author: Pierre Rioux
#
# $Id$
#

# RESTful controller for managing the Bourreau (remote execution server) resource. 
# All actions except +index+ and +show+ require *admin* privileges.
class BourreauxController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__]
  
  api_available :except  => :row_data

  before_filter :login_required
  before_filter :manager_role_required, :except  => [:index, :show, :row_data]
   
  def index #:nodoc:
    @bourreaux = base_filtered_scope RemoteResource.find_all_accessible_by_user(current_user).order("remote_resources.type DESC, remote_resources.id")
    
    #For the new form
    bourreau_group_id = ( current_project && current_project.id ) || current_user.own_group.id
    @users    = current_user.available_users
    @groups   = current_user.available_groups
    @bourreau = Bourreau.new( :user_id   => current_user.id,
                              :group_id  => bourreau_group_id,
                              :online    => true
                            )
    sensible_defaults(@bourreau)

    if current_user.has_role? :admin
      @filter_params['details'] = 'on' unless @filter_params.has_key?('details')
    end
    
    respond_to do |format|
      format.html
      format.xml  { render :xml => @bourreaux }
      format.js
    end
  end
  
  def show #:nodoc:
    @users    = current_user.available_users
    @bourreau = RemoteResource.find(params[:id])

    cb_notice "Execution Server not accessible by current user." unless @bourreau.can_be_accessed_by?(current_user)

    @info = @bourreau.info

    myusers = current_user.available_users

    @statuses = { 'TOTAL' => 0 }
    @user_tasks_info = {}

    myusers.each do |user|
      @user_tasks_info[user] ||= {}
      @user_tasks_info[user]['TOTAL'] = 0
    end
    
    myusers.each do |user|
      tasks_stats = CbrainTask.where( :bourreau_id => @bourreau.id, :user_id => user.id ).select("status, count(status) as stat_count").group(:status)

      tasks_stats.each do |t|
        status     = t.status
        stat_count = t.stat_count.to_i
        @statuses[status]               ||= 0
        @statuses[status]                += stat_count
        @statuses['TOTAL']               += stat_count
        @user_tasks_info[user]          ||= {}
        @user_tasks_info[user][status]    = stat_count
        @user_tasks_info[user]['TOTAL'] ||= 0
        @user_tasks_info[user]['TOTAL']  += stat_count
      end
    end

    @statuses_list = @statuses.keys.sort.reject { |s| s == 'TOTAL' }
    @statuses_list << 'TOTAL'

    @log = @bourreau.getlog

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @bourreau }
    end

  end
  
  def edit #:nodoc:
    @bourreau = RemoteResource.find(params[:id])
    
    cb_notice "Execution Server not accessible by current user." unless @bourreau.has_owner_access?(current_user)
    
    @users  = current_user.available_users
    @groups = current_user.available_groups

    sensible_defaults(@bourreau)

    respond_to do |format|
      format.html { render :action => :edit }
      format.xml  { render :xml => @bourreau }
    end

  end

  def create #:nodoc:
    fields    = params[:bourreau]

    @bourreau = Bourreau.new( fields )
    @bourreau.save

    if @bourreau.errors.empty?
      flash[:notice] = "Execution Server successfully created."
    end
   
    respond_to do |format|
      format.js {render :partial  => 'shared/create', :locals  => {:model_name  => 'bourreau' }}
      format.xml  do
        if @bourreau.errors.empty?
          render :xml => @bourreau 
        else
          render :xml => @bourreau.errors.to_xml, :status => :unprocessable_entity  
        end
      end
    end
  end

  def update #:nodoc:

    id        = params[:id]
    @bourreau = RemoteResource.find(id)
    
    cb_notice "This #{@bourreau.class.to_s} not accessible by current user." unless @bourreau.has_owner_access?(current_user)

    fields    = @bourreau.is_a?(Bourreau) ? params[:bourreau] : params[:brain_portal]
    
    subtype = fields.delete(:type)
  
    old_dp_cache_dir = @bourreau.dp_cache_dir
    @bourreau.update_attributes(fields)

    @users  = current_user.available_users
    @groups = current_user.available_groups
    unless @bourreau.errors.empty?
      respond_to do |format|
        format.html do
          render :action => 'edit'
        end
        format.xml { render :xml  => @bourreau.errors, :status  => :unprocessable_entity}
      end
      return
    end

    # Adjust task limits, and store them into the meta data store
    syms_limit_users = @users.map { |u| "task_limit_user_#{u.id}".to_sym }
    add_meta_data_from_form(@bourreau, [ :task_limit_total, :task_limit_user_default ] + syms_limit_users )

    if old_dp_cache_dir != @bourreau.dp_cache_dir
      old_ss = SyncStatus.where( :remote_resource_id => @bourreau.id )
      old_ss.each do |ss|
        ss.destroy rescue true
      end
      info_message = "Since the Data Provider cache directory has been changed, all\n" +
                     "synchronization status objects were reset.\n";
      unless old_dp_cache_dir.blank?
        host = @bourreau.ssh_control_host
        host = @bourreau.actres_host      if host.blank?
        host = 'localhost'                if host.blank?
        info_message += "You may have to clean up the content of the old cache directory\n" +
                        "'#{old_dp_cache_dir}' on host '#{host}'\n"
      end
      Message.send_message(current_user,
        :message_type => :system,
        :critical     => true,
        :header       => "Data Provider cache directory changed for #{@bourreau.class} '#{@bourreau.name}'",
        :description  => info_message
      )
    end

    flash[:notice] = "#{@bourreau.class.to_s} #{@bourreau.name} successfully updated"

    respond_to do |format|
      format.html do
        if params[:tool_management] != nil 
          redirect_to(:controller => "tools", :action =>"tool_management")
        else
          redirect_to(bourreaux_url)
        end
      end
      format.xml { head :ok }
    end
  end

  def destroy #:nodoc:
    id        = params[:id]
    @bourreau = RemoteResource.find(id)
    
    cb_notice "Execution Server not accessible by current user." unless @bourreau.has_owner_access?(current_user)

    tasks_left = CbrainTask.where( :bourreau_id => id ).count
    cb_notice "This Execution Server cannot be deleted as there are still #{tasks_left} tasks associated with it." if tasks_left > 0

    if @bourreau.destroy
      flash[:notice] = "Execution Server successfully deleted."
    else
      flash[:error] = "Execution Server destruction failed."
    end

    respond_to do |format|
      format.html { redirect_to :action  => :index }
      format.xml do
        if @bourreau.errors.empty?
          head :ok
        else
          render :xml => @bourreau.errors.to_xml, :status => :unprocessable_entity  
        end
      end
      format.js   { render :partial  => 'shared/destroy', :locals  => {:model_name  => 'bourreau' } }
    end

  end
  
  def row_data #:nodoc:
    @remote_resource = RemoteResource.find_accessible_by_user(params[:id], current_user)
    render :partial => 'bourreau_row_elements', :locals  => { :bour  => @remote_resource }
  end

  def load_info #:nodoc:

    if params[:current_value].blank?
      render :text  => ""
      return
    end

    @bourreau  = Bourreau.find(params[:current_value])

    respond_to do |format|
      format.html { render :partial => 'load_info', :locals => { :bourreau => @bourreau } }
      format.xml  { render :xml     => @bourreau   }
    end

  rescue => ex
    #render :text  => "#{ex.class} #{ex.message}\n#{ex.backtrace.join("\n")}"
    render :text  => '<strong style="color:red">No Information Available</strong>'
  end
  
  def refresh_ssh_keys #:nodoc:
    refreshed_bourreaux = []
    skipped_bourreaux   = []

    RemoteResource.find_all_accessible_by_user(current_user).each do |b|
      if b.is_alive?
        info = b.info
        ssh_key = info.ssh_public_key
        b.ssh_public_key = ssh_key
        b.save
        refreshed_bourreaux << b.name
      else
        skipped_bourreaux << b.name
      end
    end
    
    if refreshed_bourreaux.size > 0
      flash[:notice] = "SSH public keys have been refreshed for these Servers: " + refreshed_bourreaux.join(", ") + "\n"
    end
    if skipped_bourreaux.size > 0
      flash[:error]  = "These Servers are not alive and SSH keys couldn't be updated: " + skipped_bourreaux.join(", ") + "\n"
    end
    
    respond_to do |format|
      format.html { redirect_to :action  => :index }
      format.xml  { render :xml  => { "refreshed_bourreaux"  => refreshed_bourreaux.size, "skipped_bourreaux"  => skipped_bourreaux.size } }
    end   
  end

  def start #:nodoc:
    @bourreau = Bourreau.find(params[:id])

    cb_notice "Execution Server '#{@bourreau.name}' not accessible by current user."           unless @bourreau.can_be_accessed_by?(current_user)
    cb_notice "Execution Server '#{@bourreau.name}' is not yet configured for remote control." unless @bourreau.has_ssh_control_info?
    cb_notice "Execution Server '#{@bourreau.name}' has already been alive for #{pretty_elapsed(@bourreau.info.uptime)}." if @bourreau.is_alive?

    # New behavior: if a bourreau is marked OFFLINE we turn in back ONLINE.
    unless @bourreau.online?
      #cb_notice "This Execution Server is not marked as online."
      @bourreau.online=true
      @bourreau.save
    end

    @bourreau.start_tunnels
    cb_error "Could not start master SSH connection and tunnels for '#{@bourreau.name}'." unless @bourreau.ssh_master.is_alive?
    @bourreau.start

    if @bourreau.is_alive?
      flash[:notice] = "Execution Server '#{@bourreau.name}' started."
      @bourreau.addlog("Rails application started by user #{current_user.login}.")
      begin
        @bourreau.reload if @bourreau.auth_token.blank? # New bourreaux? Token will have just been created.
        res = @bourreau.send_command_start_workers
        raise "Failed command to start workers" unless res && res[:command_execution_status] == "OK" # to trigger rescue
        flash[:notice] += "\nWorkers on Execution Server '#{@bourreau.name}' started."
      rescue
        flash[:notice] += "\nHowever, we couldn't start the workers."
      end
    else
      flash[:error] = "Execution Server '#{@bourreau.name}' could not be started. Diagnostics:\n" +
                      @bourreau.operation_messages
    end
    
    respond_to do |format|
      format.html { redirect_to :action => :index }
      format.xml { head :ok  }
    end  

  rescue => e
    flash[:error] = e.message
    respond_to do |format|
      format.html { redirect_to :action => :index }
      format.xml { render :xml  => { :message  => e.message }, :status  => 500 }
    end
  end

  def stop #:nodoc:
    @bourreau = Bourreau.find(params[:id])

    cb_notice "Execution Server '#{@bourreau.name}' not accessible by current user."           unless @bourreau.can_be_accessed_by?(current_user)
    cb_notice "Execution Server '#{@bourreau.name}' is not yet configured for remote control." unless @bourreau.has_ssh_control_info?

    begin
      res = @bourreau.send_command_stop_workers
      raise "Failed command to stop workers" unless res && res[:command_execution_status] == "OK" # to trigger rescue
      @bourreau.addlog("Workers stopped by user #{current_user.login}.")
      flash[:notice] = "Workers on Execution Server '#{@bourreau.name}' stopped."
    rescue
      flash[:notice] = "It seems we couldn't stop the workers on Executon Server '#{@bourreau.name}'. They'll likely die by themselves."
    end

    @bourreau.online = true # to trick layers below into doing the 'stop' operation
    success = @bourreau.stop
    @bourreau.addlog("Rails application stopped.") if success
    @bourreau.online = false
    @bourreau.save
    flash[:notice] += "\nExecution Server '#{@bourreau.name}' stopped. Tunnels stopped." if success
    flash[:error]   = "Failed to stop tunnels for '#{@bourreau.name}'."                  if ! success
    
    respond_to do |format|
      format.html { redirect_to :action => :index }
      format.xml { head :ok  }
    end

  rescue => e
    flash[:error] = e.message
    respond_to do |format|
      format.html { redirect_to :action => :index }
      format.xml { render :xml  => { :message  => e.message }, :status  => 500 }
    end
  end

  private

  # Adds sensible default values to some field for
  # new objects, or existing ones being edited.
  def sensible_defaults(portal_or_bourreau)
    if portal_or_bourreau.is_a?(BrainPortal)
      if portal_or_bourreau.site_url_prefix.blank?
        guess = "http://" + request.env["HTTP_HOST"] + "/"
        portal_or_bourreau.site_url_prefix = guess
      end
    end

    if portal_or_bourreau.dp_ignore_patterns.nil? # not blank, nil!
      portal_or_bourreau.dp_ignore_patterns = [ ".DS_Store", "._*" ]
    end
  end

end
