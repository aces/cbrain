
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

# Bourreau controller for the BrainPortal interface
#
# RESTful controller for managing the Bourreau (remote execution server) resource.
# All actions except +index+ and +show+ require *admin* privileges.
class BourreauxController < ApplicationController

  include DateRangeRestriction

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  api_available :except  => :row_data

  before_action :login_required
  before_action :manager_role_required, :except  => [:index, :show, :row_data, :load_info, :rr_disk_usage, :cleanup_caches, :rr_access, :rr_access_dp]

  def index #:nodoc:
    @scope = scope_from_session
    scope_default_order(@scope, 'type')

    @base_scope = RemoteResource
      .find_all_accessible_by_user(current_user)
      .includes(:user, :group)
    @bourreaux = @scope.apply(@base_scope)

    respond_to do |format|
      format.html
      format.js
      format.xml  do
        render :xml => @bourreaux.for_api
      end
      format.json do
        render :json => @bourreaux.for_api
      end
    end
  end

  def show #:nodoc:
    @users    = current_user.available_users
    @bourreau = RemoteResource.find(params[:id])

    cb_notice "Execution Server not accessible by current user." unless @bourreau.can_be_accessed_by?(current_user)

    respond_to do |format|
      format.html # show.html.erb
      format.xml  do
        render :xml  => @bourreau.for_api
      end
      format.json do
        render :json => @bourreau.for_api
      end
    end
  end

  def info #:nodoc:
    @bourreau = RemoteResource.find(params[:id])

    cb_notice "Execution Server not accessible by current user." unless @bourreau.can_be_accessed_by?(current_user)

    @info     = @bourreau.info
    respond_to do |format|
      format.html { render :partial => "runtime_info" }
      format.xml  { render :xml  => @info }
      format.json { render :json => @info }
    end

  end

  def new #:nodoc:
    bourreau_group_id = current_assignable_group.id
    @users    = current_user.available_users
    @groups   = current_user.assignable_groups
    @bourreau = Bourreau.new( :user_id   => current_user.id,
                              :group_id  => bourreau_group_id,
                              :cache_trust_expire => 1.month.to_i.to_s,
                              :online    => true
                            )
    sensible_defaults(@bourreau)
  end

  def create #:nodoc:
    new_bourreau_attr    = bourreau_params

    @bourreau = Bourreau.new( new_bourreau_attr )

    if @bourreau.save
      @bourreau.addlog_context(self,"Created by #{current_user.login}")
      flash[:notice] = "Execution Server successfully created."

      respond_to do |format|
        format.html { redirect_to :action => :index, :format => :html }
        format.xml  { render      :xml    => @bourreau }
      end
    else
      respond_to do |format|
        format.html  { render :action => :new}
        format.xml   { render :xml    => @bourreau.errors.to_xml, :status => :unprocessable_entity }
      end
    end
  end

  def update #:nodoc:
    id        = params[:id]
    @bourreau = RemoteResource.find(id)

    cb_notice "This #{@bourreau.class.to_s} is not accessible by you." unless @bourreau.has_owner_access?(current_user)

    @users    = current_user.available_users
    @groups   = current_user.assignable_groups

    new_bourreau_attr = bourreau_params

    old_dp_cache_dir  = @bourreau.dp_cache_dir

    if ! @bourreau.update_attributes_with_logging(new_bourreau_attr, current_user,
        RemoteResource.columns_hash.keys.grep(/actres_|cache_trust|cms_|dp_|url|online|proxied_hosts|rr_timeout|ssh_|email|tunnel_|worker|logo|executable_name/)
      )
      @bourreau.reload
      respond_to do |format|
        format.html { render :action => 'show' }
        format.xml  { render :xml  => @bourreau.errors, :status  => :unprocessable_entity }
      end
      return
    end

    # Adjust task limits, and store them into the meta data store
    syms_limit_users = @users.map { |u| "task_limit_user_#{u.id}".to_sym }
    add_meta_data_from_form(@bourreau, [ :task_limit_total, :task_limit_user_default, :error_message_mailing_list ] + syms_limit_users )

    # File upload size limit (portal only)
    add_meta_data_from_form(@bourreau, [ :upload_size_limit ])

    # Help link for large uploads (shows up in the upload panel)
    add_meta_data_from_form(@bourreau, [ :large_upload_url ])

    # Options for SSH Data Providers
    add_meta_data_from_form(@bourreau, [ :use_persistent_ssh_masters_for_dps ])

    # Clean up all file synchronization stuff if the DP cache dir has changed.
    if old_dp_cache_dir != @bourreau.dp_cache_dir
      old_ss = SyncStatus.where( :remote_resource_id => @bourreau.id )
      old_ss.each do |ss|
        ss.destroy rescue true
      end
      info_message = "Since the Data Provider cache directory has been changed, all\n" +
                     "synchronization status objects were reset.\n"
      unless old_dp_cache_dir.blank?
        host = @bourreau.ssh_control_host
        host = 'localhost'                if host.blank?
        info_message += "You may have to clean up the content of the old cache directory\n" +
                        "'#{old_dp_cache_dir}' on host '#{host}'\n"
      end

      # Record new ID for local cache; this can also be done during the boot process.
      if (@bourreau.id == RemoteResource.current_resource.id)
        md5 = DataProvider.create_cache_md5
        @bourreau.update_attributes( :cache_md5 => md5 )
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
      format.html { redirect_to :action => :show }
      format.js   { render :partial => "shared/flash_update"}
      format.xml  { head        :ok }
    end
  end

  def destroy #:nodoc:
    id        = params[:id]
    @bourreau = RemoteResource.find(id)

    raise CbrainDeleteRestrictionError.new("Execution Server not accessible by current user.") unless @bourreau.has_owner_access?(current_user)

    @bourreau.destroy

    flash[:notice] = "Execution Server successfully deleted."

    respond_to do |format|
      format.html { redirect_to :action => :index}
      format.js   { redirect_to :action => :index, :format => :js}
      format.xml  { head :ok }
    end
  rescue ActiveRecord::DeleteRestrictionError => e
    flash[:error] = "Execution Server destruction failed: #{e.message.humanize}."

    respond_to do |format|
      format.html { redirect_to :action => :index}
      format.js   { redirect_to :action => :index, :format => :js}
      format.xml  { head :conflict }
    end
  end

  def row_data #:nodoc:
    @bourreaux = [ RemoteResource.find_accessible_by_user(params[:id], current_user) ]
    # FIXME its nice to re-use the bourreaux_display partial, but this flag should probably be refactored...
    @row_fetch = true
    render :partial => 'bourreaux_display'
  end

  def load_info #:nodoc:
    raise "Bad params" if params[:bourreau_id].blank? && params[:tool_config_id].blank?

    bourreau_id = params[:bourreau_id] || ToolConfig.find(params[:tool_config_id]).bourreau_id
    bourreau    = Bourreau.find(bourreau_id)

    info = {
      :latest_in_queue_delay    => bourreau.meta[:latest_in_queue_delay],
      :time_of_last_queue_delay => bourreau.meta[:time_of_latest_in_queue_delay],
      :num_active               => bourreau.cbrain_tasks.status(:active).count,
      :num_queued               => bourreau.cbrain_tasks.status(:queued).count,
      :num_processing           => bourreau.cbrain_tasks.status(:processing).count
    }

    respond_to do |format|
      format.html { render :partial => 'load_info', :locals => info.merge({ :bourreau => bourreau }) }
      format.xml  { render :xml     => info   }
      format.json { render :json    => info   }
    end

  rescue
    respond_to do |format|
      format.html { render :plain  => '<strong style="color:red">No Information Available</strong>' }
      format.xml  { head :unprocessable_entity }
      format.json { head :unprocessable_entity }
    end
  end

  def start #:nodoc:
    @bourreau = Bourreau.find(params[:id])

    cb_notice "This #{@bourreau.class.to_s} is not accessible by you."                         unless @bourreau.has_owner_access?(current_user)
    cb_notice "Execution Server '#{@bourreau.name}' not accessible by current user."           unless @bourreau.can_be_accessed_by?(current_user)
    cb_notice "Execution Server '#{@bourreau.name}' is not yet configured for remote control." unless @bourreau.has_ssh_control_info?
    cb_notice "Execution Server '#{@bourreau.name}' has already been alive for #{pretty_elapsed(@bourreau.info(:ping).uptime)}." if @bourreau.is_alive?(:ping)

    # New behavior: if a bourreau is marked OFFLINE we turn in back ONLINE.
    unless @bourreau.online?
      @bourreau.online=true
      @bourreau.save
    end

    @bourreau.start_tunnels
    cb_error "Could not start master SSH connection and tunnels for '#{@bourreau.name}'." unless @bourreau.ssh_master.is_alive?

    started_ok = @bourreau.start
    alive_ok   = started_ok && (sleep 3) && @bourreau.is_alive?(:ping)
    workers_ok = false

    if alive_ok
      @bourreau.addlog("Rails application started by user #{current_user.login}.")
      @bourreau.reload if @bourreau.auth_token.blank? # New bourreaux? Token will have just been created.
      res = @bourreau.send_command_start_workers rescue nil
      workers_ok = true if res && res[:command_execution_status] == "OK"
    end

    # Messages

    flash[:notice] = ""
    flash[:error]  = ""

    if alive_ok
      flash[:notice] = "Execution Server '#{@bourreau.name}' started."
    elsif started_ok
      flash[:error]  = "Execution Server '#{@bourreau.name}' was started but did not reply to first query:"
      Message.send_message(current_user,
        :header        => "Start Exec Server #{@bourreau.name} Problem",
        :description   => 'Bourreau started but it did not reply to first query.',
        :variable_text => @bourreau.operation_messages,
        :type          => :error,
      )
    else
      flash[:error]  = "Execution Server '#{@bourreau.name}' could not be started."
      Message.send_message(current_user,
        :header        => "Start Exec Server #{@bourreau.name} Problem",
        :description   => 'Bourreau could not be started.',
        :variable_text => @bourreau.operation_messages,
        :type          => :error,
      )
    end

    if workers_ok
      flash[:notice] += "\nWorkers on Execution Server '#{@bourreau.name}' started."
    elsif alive_ok
      flash[:error]  += "However, we couldn't start the workers."
    end

    respond_to do |format|
      format.html { redirect_to :action => :index }
      format.xml  { head workers_ok ? :ok : :internal_server_error  }  # TODO change internal_server_error ?
    end

  end

  def stop #:nodoc:
    @bourreau = Bourreau.find(params[:id])

    cb_notice "This #{@bourreau.class.to_s} is not accessible by you."                         unless @bourreau.has_owner_access?(current_user)
    cb_notice "Execution Server '#{@bourreau.name}' not accessible by current user."           unless @bourreau.can_be_accessed_by?(current_user)
    cb_notice "Execution Server '#{@bourreau.name}' is not yet configured for remote control." unless @bourreau.has_ssh_control_info?

    flash[:notice] = flash[:error] = ""

    begin
      res = @bourreau.send_command_stop_workers
      raise "Failed command to stop workers" unless res && res[:command_execution_status] == "OK" # to trigger rescue
      @bourreau.addlog("Workers stopped by user #{current_user.login}.")
      flash[:notice] += "Workers on Execution Server '#{@bourreau.name}' stopped."
    rescue
      flash[:error]  += "It seems we couldn't stop the workers on Execution Server '#{@bourreau.name}'. They'll likely die by themselves."
    end

    @bourreau.online = true # to trick layers below into doing the 'stop' operation
    boustop          = @bourreau.stop
    tunstop          = @bourreau.stop_tunnels
    @bourreau.online = false
    @bourreau.save

    @bourreau.addlog("Rails application stopped by user #{current_user.login}.")

    if boustop
      flash[:notice] += "\nExecution Server '#{@bourreau.name}' stopped."
      flash[:notice] += "\nStopped Control SSH connection." if tunstop
    else
      flash[:error]  += "\nFailed to stop Rails application for '#{@bourreau.name}'."
    end
    flash[:error]    += "\nFailed to stop Control SSH connection." if ! tunstop

    respond_to do |format|
      format.html { redirect_to :action => :index }
      format.xml { head :ok  }
    end

  rescue => e
    flash[:error] = e.message
    respond_to do |format|
      format.html { redirect_to :action => :index }
      format.xml  { render :xml  => { :message  => e.message }, :status  => 500 }
    end
  end

  # Define disk usage of remote ressource,
  # with date filtering if wanted.
  def rr_disk_usage
    date_filtering = params[:date_range] || {}
    type_filtering = params[:types]      || []

    # Time:     Present ............................................................ Past
    # In Words: now .......... older_limit ..... younger_limit ................. long ago
    # Num Secs: 0 secs ago ................. < ........................ infinite secs ago
    # Vars:     .............. @cache_older  <  @cache_younger ..........................
    #
    #                          |---- files to be deleted ----|

    date_filtering["relative_from"] ||= 50.years.to_i.to_s
    date_filtering["relative_to"]   ||= 1.week.to_i.to_s
    accessed_after  = date_filtering["relative_from"].to_i.seconds.ago
    accessed_before = date_filtering["relative_to"].to_i.seconds.ago

    # Used only relative value for determine_date_range_start_end --> harcode the 4 first values.
    (accessed_after,accessed_before) = determine_date_range_start_end(false , false, Time.now, Time.now , date_filtering["relative_from"], date_filtering["relative_to"])

    # For the interface
    @cache_younger = Time.now.to_i - accessed_after.to_i  # partial will adjust to closest value in selection box
    @cache_older   = Time.now.to_i - accessed_before.to_i # partial will adjust to closest value in selection box

    # Users in statistics table
    userlist       = current_user.available_users.all.to_a

    # Remote resources in statistics table
    rrlist         = RemoteResource.find_all_accessible_by_user(current_user).all.to_a

    # Create disk usage statistics table
    stats_options  = { :users            => userlist,
                       :remote_resources => rrlist,
                       :accessed_before  => accessed_before,
                       :accessed_after   => accessed_after,
                       :types            => type_filtering
                    }

    @report_stats    = ModelsReport.rr_usage_statistics(stats_options)

    # Keys and arrays into statistics tables, for HTML output
    @report_rrs         = @report_stats['!rrs!']
    @report_users       = @report_stats['!users!'] # does not include the 'all' column, if any

    # Filter out users for which there are no stats
    @report_users.reject! { |u| (! @report_stats[u]) || (! @report_rrs.any? { |rr| @report_stats[u][rr] }) }
    @report_users_all   = @report_users + (@report_users.size > 1 ? [ 'TOTAL' ] : [])  # users + 'all'?

    # Filter out rrs for which there are no stats
    @report_rrs.reject! { |rr| ! (@report_users_all.any? { |u| @report_stats[u] && @report_stats[u][rr] }) }

    true
  end


  # Generates report of cache disc usage by users.
  def cache_disk_usage
    bourreau_id = params[:id]       || ""
    user_ids    = params[:user_ids] || nil

    available_users = current_user.available_users
    user_ids        = user_ids ? available_users.where(:id => user_ids).ids :
                                 available_users.ids

    raise "Bad params"              if bourreau_id.blank? || user_ids.blank?
    bourreau    = Bourreau.find(bourreau_id.to_i)
    raise "Bad params"              if !bourreau.can_be_accessed_by?(current_user)
    raise "Not an Execution Server" if !bourreau.is_a?(Bourreau)

    base_relation = SyncStatus.joins(:userfile).where(:remote_resource_id => bourreau_id)

    # Create a hash table with information grouped by user.
    info_by_user = {}
    user_ids.each do |user_id|
      user_relation   = base_relation.where("userfiles.user_id" => user_id)

      number_entries  = user_relation.count
      total_size      = user_relation.sum(:size)
      number_files    = user_relation.sum(:num_files)
      number_unknown  = user_relation.where("size is null").count

      # If we want to filter empty entries
      # next if number_entries == 0 && total_size == 0 && number_files == 0 && number_unknown == 0

      user_key = "user_#{user_id}" # must be alphanum for XML report
      info_by_user[user_key] = {}
      info_by_user[user_key][:number_entries] = number_entries.to_i
      info_by_user[user_key][:total_size]     = total_size.to_i
      info_by_user[user_key][:number_files]   = number_files.to_i
      info_by_user[user_key][:number_unknown] = number_unknown.to_i
    end

    respond_to do |format|
      format.html { render :text => info_by_user.inspect }
      format.xml  { render :xml  => info_by_user }
      format.json { render :json => info_by_user }
    end

  rescue
    respond_to do |format|
      format.html { render :html  => '<strong style="color:red">No Information Available</strong>'.html_safe }
      format.xml  { head :unprocessable_entity }
      format.json { head :unprocessable_entity }
    end

  end

  # Provides the interface to trigger cache cleanup operations
  def cleanup_caches
    flash[:notice] ||= ""

    # First param is cleanup_older, which is the number
    # of second before NOW at which point files OLDER than
    # that become eligible for elimination
    cleanup_older = params[:cleanup_older] || 0
    if cleanup_older.to_s =~ /\A\d+/
      cleanup_older = cleanup_older.to_i
      cleanup_older = 50.year.to_i if cleanup_older > 50.year.to_i
    else
      cleanup_older = 50.year.to_i
    end

    # Second param is cleanup_younger, which is the number
    # of second before NOW at which point files YOUNGER than
    # that become eligible for elimination
    cleanup_younger = params[:cleanup_younger] || 0
    if cleanup_younger.to_s =~ /\A\d+/
      cleanup_younger = cleanup_younger.to_i
      cleanup_younger = 50.year.to_i if cleanup_younger > 50.year.to_i
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

    # The fourth params is a list of Userfile types (strings)
    typeslist        = Array(params[:types].presence || []) # Array(nil) is []

    # List of acceptable users
    userlist         = current_user.available_users.all

    # List of acceptable remote_resources
    rrlist           = RemoteResource.find_all_accessible_by_user(current_user).all

    # Index of acceptable users and remote_resources
    userlist_index   = userlist.index_by(&:id)
    rrlist_index     = rrlist.index_by(&:id)

    # Extract what caches are asked to be cleaned up
    rrid_to_userids = {}  # rr_id => { uid => true , uid => true , uid => true ...}
    clean_cache.each do |pair|
      next unless pair.to_s.match(/\A(\d+),(\d+)\z/)
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
        remote_resource.send_command_clean_cache(current_user.id,userids,typeslist,cleanup_older.seconds.ago,cleanup_younger.seconds.ago)
        flash[:notice] += "Sending cleanup command to #{remote_resource.name}."
      rescue
        flash[:notice] += "Could not contact #{remote_resource.name}."
      end
    end

    date_filtering                              = {}
    date_filtering["relative_from"]             = cleanup_younger
    date_filtering["relative_to"]               = cleanup_older

    redirect_to :action => :rr_disk_usage, :date_range => date_filtering, :types => typeslist

  end

  # Define remote ressource and users accessible/available by
  # the current user.
  def rr_access
    @remote_r = RemoteResource.find_all_accessible_by_user(current_user).all.sort { |a,b| a.name <=> b.name }
    @users    = current_user.available_users.all.sort { |a,b| a.login <=> b.login }
  end

  # Define which remote resource can acces which data provider.
  def rr_access_dp
    @rrs = RemoteResource.find_all_accessible_by_user(current_user).all.sort do |a,b|
           (b.online?.to_s <=> a.online?.to_s).nonzero? ||
           (b.type         <=> a.type).nonzero?         ||
           (a.name         <=> b.name)
    end
    @dps = DataProvider.find_all_accessible_by_user(current_user).all.sort   do |a,b|
           (b.online?.to_s       <=> a.online?.to_s).nonzero?       ||
           (a.is_browsable?.to_s <=> b.is_browsable?.to_s).nonzero? ||
           (a.name               <=> b.name)
    end

    refresh    = params[:refresh]
    refresh_bs = []
    if refresh == 'all'
      refresh_bs = @rrs
    else
      refresh_bs = @rrs.select { |b| b.id == refresh.to_i }
    end

    sent_refresh = [] # for flash message
    refresh_bs.each do |b|
      if b.online? && b.has_owner_access?(current_user) && (! b.meta[:data_provider_statuses_last_update] || b.meta[:data_provider_statuses_last_update] < 1.minute.ago)
        b.send_command_check_data_providers(@dps.map(&:id)) rescue true
        sent_refresh << b.name
      end
    end

    if ! refresh.blank?
      if sent_refresh.size > 0
        flash[:notice] = "Sent a request to check the Data Providers to these servers: #{sent_refresh.join(", ")}\n" +
                         "This will be done in background and can take several minutes before the reports are ready."
      else
        flash[:notice] = "No refresh needed, access information is recent enough."
      end
      redirect_to :action => :rr_access_dp  # try again, without the 'refresh' param
    end

  end

  # API method to copy files from one DP to another via a bourreau;
  # unlike the file_copy method, this method will select which bourreau
  # to use dynamically, based on the ones that have the less activity already
  # scheduled. The set of bourreaux to consider can be given by providing a
  # set of bourreau_ids or a set of bourreau_group_ids in parameter (the
  # default is to consider all currently online bourreaux)
  def dispatcher_file_copy #:nodoc:
    userfile_ids       = params[:userfile_ids]
    data_provider_id   = params[:data_provider_id]
    bourreau_ids       = Array(params[:bourreau_ids])  # optional
    bourreau_group_ids = Array(params[:bourreau_group_ids]) # optional
    bypass_cache       = params[:bypass_cache].present?
    patterns           = params[:sync_select_patterns].presence # optional
    unregister         = params[:unregister_after_copy].present?

    # Find files and destination DP
    data_provider      = DataProvider.find(data_provider_id)
    userfile_ids       = Userfile.find_all_accessible_by_user(current_user, :access_requested => :read)
                          .where(:id => userfile_ids).pluck(:id)

    # Validate things
    cb_error "DataProvider not available" if data_provider.read_only || !data_provider.can_be_accessed_by?(current_user)
    cb_error "No files selected"          if userfile_ids.empty?

    # Select potential bourreaux
    bourreaux = Bourreau.where(:online => true)
    bourreaux = bourreaux.where(:id => bourreau_ids)             if bourreau_ids.present?
    bourreaux = bourreaux.where(:group_id => bourreau_group_ids) if bourreau_group_ids.present?
    bourreaux = bourreaux.to_a.select { |b| b.can_be_accessed_by?(current_user) }
    cb_error "No bourreaux available" if bourreaux.empty?

    # Select one best bourreau
    bids = bourreaux.map(&:id)
    active_counts = BackgroundActivity
      .where(:remote_resource_id => bids, :status => 'InProgress')
      .group(:remote_resource_id)
      .count
    bids.each { |bid| active_counts[bid] ||= 0 } # adds 0 to all missing counts
    min_count = active_counts.map { |bid,count| count }.min
    selected_bids = active_counts.map { |bid,count| bid if count == min_count }.compact
    selected_bid  = selected_bids.shuffle.first

    # Create the copy request as a BackgroundActivity object
    bac_klass = unregister ? BackgroundActivity::CopyFileAndUnregister : BackgroundActivity::CopyFile
    bac = bac_klass.setup!(
      current_user.id, userfile_ids, selected_bid, data_provider_id,
      :bypass_cache         => bypass_cache,
      :sync_select_patterns => Array(patterns).presence,
    )
    bac.update_column(:retry_count, 3) if bac.id # hardcoded for the moment

    render :json => { :status => "ok", :userfile_ids => userfile_ids, :background_activity_id => bac.id }
  end

  private

  def bourreau_params #:nodoc:
    params.require(:bourreau).permit(
      :name, :user_id, :group_id, :online, :read_only, :description,
      :ssh_control_user, :ssh_control_host, :ssh_control_port, :ssh_control_rails_dir,
      :cache_md5, :portal_locked, :cache_trust_expire,
      :time_zone, :site_url_prefix, :dp_cache_dir, :dp_ignore_patterns, :cms_class,
      :nh_site_url_prefix, :nh_support_email, :nh_system_from_email,
      :cms_default_queue, :cms_extra_qsub_args, :cms_shared_dir, :workers_instances,
      :workers_chk_time, :workers_log_to, :workers_verbose, :help_url, :rr_timeout, :proxied_host,
      :spaced_dp_ignore_patterns, :support_email, :system_from_email, :external_status_page_url,
      :docker_executable_name, :docker_present, :singularity_executable_name, :singularity_present,
      :small_logo, :large_logo, :license_agreements
    )
  end

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
