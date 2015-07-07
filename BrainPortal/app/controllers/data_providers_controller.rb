
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

# RESTful controller for the DataProvider resource.


class DataProvidersController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  api_available :except => [:cleanup]

  before_filter :login_required
  before_filter :manager_role_required, :only => [:new, :create]
  before_filter :admin_role_required,   :only => [:report, :repair]

  API_HIDDEN_ATTRIBUTES = [ :cloud_storage_client_identifier, :cloud_storage_client_token ]

  def index #:nodoc:
    @filter_params["sort_hash"]["order"] ||= "data_providers.name"

    @header_scope   = DataProvider.find_all_accessible_by_user(current_user)
    @filtered_scope = base_filtered_scope @header_scope.includes(:user, :group)
    @data_providers = base_sorted_scope @filtered_scope

    if current_user.has_role? :admin_user
      @filter_params['details'] = 'on' unless @filter_params.has_key?('details')
    end

    respond_to do |format|
      format.html
      format.xml  do
        @data_providers.each { |dp| dp.hide_attributes(API_HIDDEN_ATTRIBUTES) }
        render :xml  => @data_providers
      end
      format.json do
        @data_providers.each { |dp| dp.hide_attributes(API_HIDDEN_ATTRIBUTES) }
        render :json => @data_providers.to_json(methods: [:type, :is_browsable?, :is_fast_syncing?, :allow_file_owner_change?])
      end
      format.js
    end
  end

  # GET /data_providers/1
  # GET /data_providers/1.xml
  def show  #:nodoc:
    data_provider_id = params[:id]
    @provider        = DataProvider.find(data_provider_id)

    cb_notice "Provider not accessible by current user." unless @provider.can_be_accessed_by?(current_user)


    respond_to do |format|
      format.html # show.html.erb
      format.xml  {
          @provider.hide_attributes(API_HIDDEN_ATTRIBUTES)
          render :xml  => @provider
      }
      format.json {
          @provider.hide_attributes(API_HIDDEN_ATTRIBUTES)
          render :json => @provider
      }
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

    render :partial => "new"
  end

  def create #:nodoc:
    @provider = DataProvider.sti_new(params[:data_provider])
    @provider.user_id  ||= current_user.id # disabled field in form DOES NOT send value!
    @provider.group_id ||= (( current_project && current_project.id ) || current_user.own_group.id)

    if @provider.save
      add_meta_data_from_form(@provider, [:must_move, :no_uploads, :no_viewers, :browse_gid])
      @provider.addlog_context(self,"Created by #{current_user.login}")
      flash[:notice] = "Provider successfully created."
      respond_to do |format|
        format.js   { redirect_to :action => :index, :format => :js  }
        format.xml  { render :xml   => @provider }
        format.json { render :json  => @provider }
      end
    else
      @typelist = get_type_list
      respond_to do |format|
        format.js   { render :partial  => "shared/failed_create", :locals => {:model_name => "data_provider"} }
        format.xml  { render :xml      => @provider.errors, :status  => :unprocessable_entity }
        format.json { render :json     => @provider.errors, :status  => :unprocessable_entity }
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
        format.json { head :forbidden }
       end
       return
    end

    fields    = params[:data_provider] || {}
    fields.delete(:type)

    if @provider.update_attributes_with_logging(fields, current_user,
         %w(
           remote_user remote_host remote_port remote_dir
           not_syncable cloud_storage_client_identifier cloud_storage_client_token
         )
      )
      meta_flags_for_restrictions = (params[:meta] || {}).keys.grep(/^dp_no_copy_\d+$|^rr_no_sync_\d+$/)
      add_meta_data_from_form(@provider, [:must_move, :no_uploads, :no_viewers, :browse_gid] + meta_flags_for_restrictions)
      flash[:notice] = "Provider successfully updated."
      respond_to do |format|
        format.html { redirect_to :action => :show }
        format.xml  { render :xml   => @provider }
        format.json { render :json  => @provider }
      end
    else
      @provider.reload
      respond_to do |format|
        format.html { render :action => 'show' }
        format.xml  { render :xml    => @provider.errors, :status  => :unprocessable_entity }
        format.json { render :json   => @provider.errors, :status  => :unprocessable_entity }
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
      format.html { redirect_to :action => :index }
      format.js   { redirect_to :action => :index, :format => :js } # no longer used?
      format.xml  { head :ok }
      format.json { head :ok }
    end
  rescue ActiveRecord::DeleteRestrictionError => e
    flash[:error]  = "Provider not destroyed: #{e.message}"

    respond_to do |format|
      format.html { redirect_to :action => :index }
      format.js   { redirect_to :action => :index, :format => :js } # no longer used?
      format.xml  { head :conflict }
      format.json { head :conflict }
    end
  end

  # Returns information about the aliveness of +dataprovider+.
  def is_alive
    @provider = DataProvider.find_accessible_by_user(params[:id], current_user)
    is_alive =  @provider.is_alive?

    respond_to do |format|
      format.html { render :text => red_if( ! is_alive, "<span>Yes</span>".html_safe, "No" ) }
      format.xml  { render :xml  => { :is_alive => is_alive } }
      format.json { render :json => { :is_alive => is_alive } }
    end
  end

  # Returns a report about the +dataprovider+ disk usage by users.
  def disk_usage
    dataprovider_id = params[:id]       || ""
    user_ids        = params[:user_ids] || nil

    available_users = current_user.available_users
    user_ids        = user_ids ? available_users.where(:id => user_ids).raw_first_column(:id) :
                                 available_users.raw_first_column(:id)

    raise "Bad params"              if dataprovider_id.blank? || user_ids.blank?
    dataprovider    = DataProvider.find(dataprovider_id.to_i)
    raise "Bad params"              if !dataprovider.can_be_accessed_by?(current_user)

    base_relation = Userfile.where(:user_id => user_ids).where(:data_provider_id => dataprovider_id)

    # Create a hash table with information grouped by user.
    info_by_user = {}
    user_ids.each do |user_id|
      user_relation   = base_relation.where(:user_id => user_id)

      number_entries  = user_relation.count
      total_size      = user_relation.sum(:size)
      number_files    = user_relation.sum(:num_files)
      number_unknown  = user_relation.where("size is null").count

      # If we want to filter empty entries
      # next if number_entries == 0 && total_size == 0 && number_files == 0 && number_unknown == 0

      info_by_user[user_id] = {}
      info_by_user[user_id][:number_entries]  =  number_entries.to_i
      info_by_user[user_id][:total_size]      =  total_size.to_i
      info_by_user[user_id][:number_files]    =  number_files.to_i
      info_by_user[user_id][:number_unknown]  =  number_unknown.to_i
    end

    respond_to do |format|
      format.html { render :text => info_by_user.inspect }
      format.xml  { render :xml  => info_by_user }
      format.json { render :json => info_by_user }
    end

  rescue
    respond_to do |format|
      format.html { render :text  => '<strong style="color:red">No Information Available</strong>' }
      format.xml  { head :unprocessable_entity }
      format.json { head :unprocessable_entity }
    end

  end

  # Generates list of providers accessible by the current user.
  # Generates list of users available by the current user.
  def dp_access
    @providers = DataProvider.find_all_accessible_by_user(current_user).all.sort do |a,b|
                   (b.online?.to_s       <=> a.online?.to_s).nonzero?       ||
                   (a.is_browsable?.to_s <=> b.is_browsable?.to_s).nonzero? ||
                   (a.name               <=> b.name)
                 end
    @users     = current_user.available_users.all.sort do |a,b|
                   (a.account_locked?.to_s <=> b.account_locked?.to_s) ||
                   (a.login                <=> b.login)
                 end
  end

  # Generates list of providers accessible by the current user.
  def dp_transfers
    @providers = DataProvider.find_all_accessible_by_user(current_user).all.sort do |a,b|
                   (b.online?.to_s       <=> a.online?.to_s).nonzero?       ||
                   (a.is_browsable?.to_s <=> b.is_browsable?.to_s).nonzero? ||
                   (a.name               <=> b.name)
                 end
  end

  # Browse the files of a data provider.
  # This action is only available for data providers that are browsable.
  # Both registered and unregistered files will appear in the list.
  def browse
    @provider = DataProvider.find_accessible_by_user(params[:id], current_user)

    unless @provider.is_browsable?(current_user) && @provider.online?
      flash[:error]  = "You cannot browse Data Provider '#{@provider.name}'.\n"
      flash[:error] += "It is currently marked as 'offline'." if ! @provider.online
      respond_to do |format|
        format.html { redirect_to :action => :index }
        format.xml  { render :xml  => { :error => flash[:error] }, :status => :forbidden }
        format.json { render :json => { :error => flash[:error] }, :status => :forbidden }
      end
      return
    end

    @filter_params["browse_hash"] ||= {}
    @per_page  = @filter_params["browse_hash"]["per_page"]
    validate_pagination_values # validates @per_page and @current_page
    as_user_id = params[:as_user_id].presence || @filter_params["browse_hash"]["as_user_id"].presence || current_user.id
    @as_user   = current_user.available_users.where(:id => as_user_id).first || current_user
    @filter_params["browse_hash"]["as_user_id"] = @as_user.id.to_s

    begin
      # [ base, size, type, mtime ]
      @fileinfolist = get_recent_provider_list_all(@provider, @as_user, params[:refresh])
    rescue => e
      flash[:error] = 'Cannot get list of files. Maybe the remote directory doesn\'t exist or is locked?' #emacs fails to parse this properly so I switched to single quotes.
      Message.send_internal_error_message(User.find_by_login('admin'), "Browse DP exception", e, params) rescue nil
      respond_to do |format|
        format.html { redirect_to :action => :index }
        format.xml  { render :xml   => flash[:error], :status  => :unprocessable_entity}
        format.json { render :json  => flash[:error], :status  => :unprocessable_entity}
      end
      return
    end

    # Let's add three more custom attributes:
    # - the userfile if the file is already registered
    # - the state_ok flag that tell whether or not it's OK to register/unregister
    # - a message.
    if @fileinfolist.size > 0
       @fileinfolist[0].class.class_eval("attr_accessor :userfile, :state_ok, :message, :userfile_id")
    end

    # NOTE: next paragraph for initializing registered_files is also in register() action
    registered_files = Userfile.where( :data_provider_id => @provider.id )
    # On data providers where files are stored in a per user subdir, we limit our
    # search of what's registered to only those belonging to @as_user
    registered_files = registered_files.where( :user_id => @as_user.id ) if ! @provider.allow_file_owner_change?
    registered_files = registered_files.all.index_by(&:name)

    @fileinfolist.each do |fi|
      fi_name  = fi.name
      fi_type  = fi.symbolic_type

      fi.userfile = nil
      fi.message  = ""
      fi.state_ok = false

      registered = registered_files[fi_name]
      if registered
        fi.userfile    = registered # the userfile object itself
        fi.userfile_id = registered.id
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

    # Search by name
    if @filter_params["browse_hash"]["name_like"].present?
      search_term   = @filter_params["browse_hash"]["name_like"].to_s.downcase
      @fileinfolist = @fileinfolist.select{|file| file.name.to_s.downcase.index(search_term)}
    end

    @file_count   = @fileinfolist.count
    unless request.format.to_sym == :xml || request.format.to_sym == :json
      @fileinfolist = WillPaginate::Collection.create(@current_page, @per_page) do |pager|
        pager.replace(@fileinfolist[(@current_page-1)*@per_page, @per_page] || [])
        pager.total_entries = @file_count
        pager
      end
    end

    current_session.save_preferences_for_user(current_user, :data_providers, :browse_hash)

    respond_to do |format|
      format.html
      format.xml do
        @fileinfolist.each { |fil| fil.instance_eval {remove_instance_variable :@userfile} }
        render :xml  => @fileinfolist
      end
      format.json do
        @fileinfolist.each { |fil| fil.instance_eval {remove_instance_variable :@userfile} }
        render :json  => @fileinfolist
      end
      format.js
    end

  end

  # Register a list of files into the system.
  # The files' meta data will be saved as Userfile resources.
  # This method is (unfortunately) also used to unregister files, and delete them (on the browsable side)
  def register
    # TODO: refactor completely!
    @provider  = DataProvider.find_accessible_by_user(params[:id], current_user)

    @filter_params["browse_hash"] ||= {}
    as_user_id = params[:as_user_id].presence || @filter_params["browse_hash"]["as_user_id"].presence || current_user.id
    @as_user = current_user.available_users.where(:id => as_user_id).first || current_user
    @filter_params["browse_hash"]["as_user_id"] = @as_user.id.to_s

    unless @provider.is_browsable?(current_user)
      flash[:error] = "You cannot register files from this provider."
      respond_to do |format|
        format.html { redirect_to :action => :index }
        format.xml  { render :xml   => { :error  =>  flash[:error] }, :status  => :forbidden }
        format.json { render :json  => { :error  =>  flash[:error] }, :status  => :forbidden }
      end
      return
    end

    basenames = params[:basenames] || []
    filetypes = params[:filetypes] || []
    basenames = [basenames] unless basenames.is_a? Array
    filetypes = [filetypes] unless filetypes.is_a? Array

    # Find out what we'll do with all these files
    do_unreg  = params.has_key?(:unregister)
    do_erase  = params.has_key?(:delete)

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

    # Create an association { basename => type } as provided by the form
    base2type = {}
    filetypes.select { |typebase| ! typebase.empty? }.each do |typebase|
      next unless typebase.match(/^(\w+)-(\S+)$/)
      type = $1
      base = $2
      base2type[base] = type
    end

    # Counters and stats
    newly_registered_userfiles      = []
    previously_registered_userfiles = []
    num_unregistered = 0
    num_erased       = 0
    num_skipped      = 0

    flash[:error]  = ""
    flash[:notice] = ""

    legal_subtypes = Userfile.descendants.map(&:name).index_by { |x| x }

    # NOTE: next paragraph for initializing registered_files is also in browse() action
    registered_files = Userfile.where( :data_provider_id => @provider.id )
    # On data providers where files are stored in a per user subdir, we limit our
    # search of what's registered to only those belonging to @as_user
    registered_files = registered_files.where( :user_id => @as_user.id ) if ! @provider.allow_file_owner_change?
    registered_files = registered_files.all.index_by(&:name)

    basenames.each do |basename|

      # Unregister files

      if do_unreg || do_erase
        userfile = registered_files[basename]
        if userfile.blank?
          num_skipped += 1 unless do_erase
        elsif ! userfile.has_owner_access?(current_user)
          flash[:error] += "Error: file #{basename} is not registered such that you have the necessary permissions to unregister it. File not unregistered.\n"
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
        temp_class    = FileCollection   # erasing should work whether or not target really is a directory or not; if not change this
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
      if base2type.has_key?(basename)
        subtype = base2type[basename]
        if subtype == "Unset" || ( ! legal_subtypes[subtype] )
          flash[:error] += "Error: entry #{basename} not provided with a proper type. File not registered.\n"
          num_skipped += 1
          next
        end
      end

      file_group_id   = params[:other_group_id].to_i unless params[:other_group_id].blank?
      file_group_id ||= current_project.try(:id) || current_user.own_group.id
      file_group_id   = current_user.own_group.id unless current_user.available_groups.map(&:id).include?(file_group_id)

      subclass = Class.const_get(subtype)
      userfile = subclass.new( :name             => basename,
                               :user_id          => @as_user.id, # cannot use current_user, since it might be a vault_ssh dp
                               :group_id         => file_group_id,
                               :data_provider_id => @provider.id )

      registered_file = registered_files[basename]
      if registered_file
        previously_registered_userfiles << registered_file
      elsif userfile.save
        newly_registered_userfiles << userfile
        userfile.addlog_context(self, "Registered on DataProvider '#{@provider.name}' as '#{userfile.name}' by #{current_user.login}.")
      else
        flash[:error] += "Error: could not register #{subtype} '#{basename}'... maybe the file exists already?\n"
        num_skipped += 1
      end

    end # loop to register/unregister files

    if num_skipped > 0
      flash[:notice] += "Skipped #{num_skipped} files.\n"
    end

    if newly_registered_userfiles.size > 0
      clear_browse_provider_local_cache_file(@as_user, @provider) unless request.format.to_sym == :xml || request.format.to_sym == :json
      flash[:notice] += "Registered #{newly_registered_userfiles.size} files.\n"
      if @as_user != current_user
        flash[:notice] += "Important note! Since you were browsing as user '#{@as_user.login}', the files were registered as belonging to that user instead of you!\n"
      end
    elsif num_erased > 0
      clear_browse_provider_local_cache_file(@as_user, @provider) unless request.format.to_sym == :xml || request.format.to_sym == :json
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

      api_response = {  :notice                                => flash[:notice],
                        :error                                 => flash[:error],
                        :newly_registered_userfiles            => newly_registered_userfiles,
                        :previously_registered_userfiles       => previously_registered_userfiles,
                        :userfiles_in_transit                  => [],
                        :num_unregistered                      => num_unregistered,
                        :num_erased                            => num_erased,
                      } if request.format.to_s =~ /xml|json/i

      respond_to do |format|
        format.html { redirect_to :action => :browse }
        format.xml  { render      :xml    => api_response }
        format.json { render      :json   => api_response }
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
      success_list  = []
      failed_list   = {}
      CBRAIN.spawn_with_active_records(:admin, "#{move_or_copy} Registered Files") do
        to_operate.each do |u|
          begin
            if move_or_copy == "MOVE"
              u.provider_move_to_otherprovider(new_dp)
              u.set_size!
            elsif move_or_copy == "COPY" # and no ELSE !
              new = u.provider_copy_to_otherprovider(new_dp)
              u.destroy rescue true # will simply unregister
              new.set_size!
            end
            success_list << u
          rescue => ex
            (failed_list[ex.message] ||= []) << u
          end
        end # each file

        # Message for successful actions
        if success_list.present?
          notice_message_sender("Files #{past_tense} during registration", success_list)
        end
        # Message for failed actions
        if failed_list.present?
          error_message_sender("Files FAILED to be #{past_tense} during registration", failed_list)
        end
      end # spawn
    end # if move or copy

    api_response = {  :notice                                => flash[:notice],
                      :error                                 => flash[:error],
                      :newly_registered_userfiles            => newly_registered_userfiles,
                      :previously_registered_userfiles       => previously_registered_userfiles,
                      :userfiles_in_transit                  => to_operate,
                      :num_unregistered                      => num_unregistered,
                      :num_erased                            => num_erased,
                    } if request.format.to_s =~ /xml|json/i

    respond_to do |format|
      format.html { redirect_to :action => :browse }
      format.xml  { render      :xml    => api_response }
      format.json { render      :json   => api_response }
    end

  end

  # Report inconsistencies in the data provider.
  def report
    @provider = DataProvider.find(params[:id])
    @issues   = @provider.provider_report(params[:reload])

    respond_to do |format|
      format.html # report.html.erb
      format.xml  { render :xml  => { :issues => @issues } }
      format.json { render :json => { :issues => @issues } }
    end
  end

  # Repair one or more inconsistencies in the data provider.
  def repair
    @provider = DataProvider.find(params[:id])
    @issues   = @provider.provider_report.select { |i| params[:issue_ids].include? i[:id].to_s }

    # Try to repair the inconsistencies (or issues)
    failed_list  = []
    success_list = []
    @issues.each do |issue|
      begin
        @provider.provider_repair(issue)
        success_list << issue
      rescue => ex
        failed_list  << [issue, ex]
      end
    end

    # Display a message reporting how many issues were repaired
    unless @issues.empty?
      if failed_list.empty?
        Message.send_message(current_user,
          :message_type  => :notice,
          :header        => "#{@issues.size} issue(s) repaired successfully.",
          :variable_text => success_list.map do |issue|
            line  = ["|#{issue[:message]}|: repaired"]
            line << " (action taken: #{issue[:action].to_s.titleize})" if issue[:action]
            line << "\n"
            line.join
          end.join
        )
      else
        Message.send_message(current_user,
          :message_type  => :error,
          :header        => "Out of #{@issues.size} issue(s), #{failed_list.size} could not be repaired:",
          :variable_text => failed_list.map { |issue,ex| "|#{issue[:message]}|: #{ex.message}\n" }.join
        )
      end
    end

    api_response = {
      :repaired => success_list,
      :failed   => failed_list.map { |issue,ex| { :issue => issue, :exception => ex.message } }
    }

    respond_to do |format|
      format.html { redirect_to :action => :report }
      format.xml  { render      :xml    => api_response }
      format.json { render      :json   => api_response }
    end
  end

  private

  def get_type_list #:nodoc:
    data_provider_list = (check_role(:site_manager) || check_role(:admin_user)) ? DataProvider.descendants.map(&:name).sort : %w{ SshDataProvider }     
    grouped_options = data_provider_list.hashed_partitions { |name| name.constantize.pretty_category_name }
    grouped_options.delete(nil) # data providers that can not be on this list return a category name of nil, so we remove them
    grouped_options.to_a
  end

  # Note: the following methods should all be part of one of the subclasses of DataProvider, probably.

  def browse_provider_local_cache_file(user, provider) #:nodoc:
    cache_file = "/tmp/dp_cache_list_all_#{user.id}.#{provider.id}"
    cache_file
  end

  def get_recent_provider_list_all(provider, as_user = current_user, refresh = false) #:nodoc:

    refresh = false if refresh.blank? || refresh.to_s == 'false'

    # Check to see if we can simply reload the cached copy
    cache_file = browse_provider_local_cache_file(as_user, provider)
    if ! refresh && File.exist?(cache_file) && File.mtime(cache_file) > 60.seconds.ago
       filelisttext = File.read(cache_file)
       fileinfolist = YAML.load(filelisttext)
       return fileinfolist
    end

    # Get info from provider
    fileinfolist = provider.provider_list_all(as_user)

    # Write a new cached copy
    save_browse_provider_local_cache_file(as_user, provider, fileinfolist)

    # Return it
    fileinfolist
  end

  def save_browse_provider_local_cache_file(user, provider, fileinfolist) #:nodoc:
    cache_file = browse_provider_local_cache_file(user, provider)
    tmpcachefile = cache_file + ".#{Process.pid}.tmp";
    File.open(tmpcachefile,"w") do |fh|
       fh.write(YAML.dump(fileinfolist))
    end
    File.rename(tmpcachefile,cache_file) rescue true  # crush it
  end

  def clear_browse_provider_local_cache_file(user, provider) #:nodoc:
    cache_file = browse_provider_local_cache_file(user, provider)
    File.unlink(cache_file) rescue true
  end

end
