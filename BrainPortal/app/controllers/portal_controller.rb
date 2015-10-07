
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

# Controller for the entry point into the system.
class PortalController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include DateRangeRestriction

  before_filter :login_required, :except => [ :credits, :about_us, :welcome ]  # welcome is here so that the redirect to the login page doesn't show the error message
  before_filter :admin_role_required, :only => :portal_log

  # Display a user's home page with information about their account.
  def welcome #:nodoc:
    unless current_user
      redirect_to login_path
      return
    end

    if current_user.has_role?(:normal_user)
      redirect_to start_page_path
      return
    end

    @num_files              = current_user.userfiles.count
    @groups                 = current_user.has_role?(:admin_user) ? current_user.groups.order(:name) : current_user.available_groups.order(:name)
    @default_data_provider  = DataProvider.find_by_id(current_user.meta["pref_data_provider_id"])
    @default_bourreau       = Bourreau.find_by_id(current_user.meta["pref_bourreau_id"])

    if current_user.has_role? :admin_user
      @active_users = CbrainSession.active_users
      @active_users.unshift(current_user) unless @active_users.include?(current_user)
      if request.post?
        CbrainSession.clean_sessions
        CbrainSession.purge_sessions(params[:session_clear].to_i.seconds.ago) unless
          params[:session_clear].blank?

        if params[:lock_portal] == "lock"
          BrainPortal.current_resource.lock!
          BrainPortal.current_resource.addlog("User #{current_user.login} locked this portal.")
          message = params[:message] || ""
          message = "" if message =~ /\(lock message\)/ # the default string
          BrainPortal.current_resource.meta[:portal_lock_message] = message
          flash.now[:notice] = "This portal has been locked."
        elsif params[:lock_portal] == "unlock"
          BrainPortal.current_resource.unlock!
          BrainPortal.current_resource.addlog("User #{current_user.login} unlocked this portal.")
          flash.now[:notice] = "This portal has been unlocked."
          flash.now[:error] = ""
        end
      end
    end

    bourreau_ids = Bourreau.find_all_accessible_by_user(current_user).raw_first_column("remote_resources.id")
    user_ids     = current_user.available_users.raw_first_column(:id)
    @tasks       = CbrainTask.real_tasks.not_archived.where(:user_id => user_ids, :bourreau_id => bourreau_ids).order( "updated_at DESC" ).limit(10).all
    @files       = Userfile.find_all_accessible_by_user(current_user).where(:hidden => false).order( "updated_at DESC" ).limit(10).all
  end

  def portal_log #:nodoc:

    # Number of lines to show
    num_lines = (params[:num_lines] || 5000).to_i
    num_lines = 100 if num_lines < 100
    num_lines = 20_000 if num_lines > 20_000

    # Filters
    user_name = params[:user_login].presence
    inst_name = params[:log_inst].to_s.presence
    meth_name = params[:log_meth].to_s.presence
    ctrl_name = params[:log_ctrl].to_s.presence
    ms_min    = params[:ms_min].presence.try(:to_i)

    # Hide some less important lines
    remove_egrep = []
    remove_egrep << "^Started "       if params[:hide_started].presence    == "1"
    remove_egrep << "^ *Processing "  if params[:hide_processing].presence == "1"
    remove_egrep << "^ *Parameters: " if params[:hide_parameters].presence == "1"
    remove_egrep << "^ *Rendered"     if params[:hide_rendered].presence   == "1"
    remove_egrep << "^ *Redirected"   if params[:hide_redirected].presence == "1"
    remove_egrep << "^User:"          if params[:hide_user].presence       == "1"
    remove_egrep << "^Completed"      if params[:hide_completed].presence  == "1"
    # Note that in production, 'SQL', 'CACHE', 'AREL' and 'LOAD' are never shown.
    remove_egrep << "^ *SQL "         if params[:hide_sql].presence        == "1"
    remove_egrep << "^ *CACHE "       if params[:hide_cache].presence      == "1"
    remove_egrep << "^ *AREL "        if params[:hide_arel].presence       == "1"
    remove_egrep << "^ *[^ ]* Load"   if params[:hide_load].presence       == "1"

    # Hiding some lines disable some filters, because we hide before we filter. :-(
    meth_name = nil if params[:hide_started].presence   == "1"
    ctrl_name = nil if params[:hide_started].presence   == "1"
    user_name = nil if params[:hide_user].presence      == "1"
    inst_name = nil if params[:hide_user].presence      == "1"
    ms_min    = nil if params[:hide_completed].presence == "1"

    # Extract the raw data with escape sequences filtered.

    # Version 1: tail first, filter after. We get less lines than expected.
    #command  = "tail -#{num_lines} #{Rails.configuration.paths.log.first} | perl -pe 's/\\e\\[[\\d;]*\\S//g'"
    #command += " | grep -E -v '#{remove_egrep.join("|")}'" if remove_egrep.size > 0

    # Version 2: filter first, tail after. Bad if log file is really large, but perl is fast.
    command  = "perl -pe 's/\\e\\[[\\d;]*\\S//g' #{Rails.configuration.paths["log"].first.to_s.bash_escape}"
    command += " | grep -E -v '#{remove_egrep.join("|")}'" if remove_egrep.size > 0
    command += " | tail -#{num_lines}"

    # Slurp it all
    log = IO.popen(command, "r") { |io| io.read }
    log.gsub!(/^(Started)/, "\n\\1")

    @user_counts = Hash.new(0) # For select box.

    # Filter by username, instance name, method, controller or min milliseconds
    if user_name || inst_name || meth_name || ctrl_name || ms_min
      filtlogs   = []
      paragraph  = []
      found_user = nil
      found_inst = nil
      found_meth = nil
      found_ctrl = nil
      found_ms   = 0

      (log.split("\n") + [ "\n" ]).each do |line|
        next unless line
        next unless line =~ /^Started (\S+) "\/(\w*)/ || ! paragraph.empty?

        found_meth, found_ctrl = Regexp.last_match[1,2] if Regexp.last_match
        paragraph << '' if paragraph.empty?
        paragraph << line

        if line =~ /^User: (\S+)/
          found_user = Regexp.last_match[1]
          @user_counts[found_user] += 1
          if line =~ /on instance (\S+)/
            found_inst = Regexp.last_match[1]
          end
        elsif line =~ /^Completed.*in (\d+(?:.\d+)?)ms/
          found_ms = Regexp.last_match[1].to_i
          filtlogs += paragraph if (!user_name || found_user == user_name) &&
                                   (!inst_name || found_inst == inst_name) &&
                                   (!meth_name || found_meth == meth_name) &&
                                   (!ctrl_name || found_ctrl == ctrl_name) &&
                                   (!ms_min    || found_ms   >= ms_min)
          paragraph = []
        end
      end
      log = filtlogs.join("\n")
    else
      log.split("\n").each do |line|
        if line =~ /^User: (\S+)/
          found_user = Regexp.last_match[1]
          @user_counts[found_user] += 1
        end
      end
    end

    if log.present?
      log = colorize_logs(log)
    else
      log = <<-NO_SHOW
        <span style=\"color:yellow; font-weight:bold\">
          (No logs entries found using your filters within the last #{num_lines} lines of the #{Rails.env} log)
        </span>
      NO_SHOW
    end

    @portal_log = log.html_safe
  end

  def show_license #:nodoc:
    @license = params[:license].gsub(/[^\w-]+/, "")
  end

  def sign_license #:nodoc:
    @license = params[:license]
    unless params.has_key?(:agree)
      flash[:error] = "CBRAIN cannot be used without signing the End User Licence Agreement."
      redirect_to "/logout"
      return
    end
    num_checkboxes = params[:num_checkboxes].to_i
    if num_checkboxes > 0
      num_checks = params.keys.grep(/^license_check/).size
      if num_checks < num_checkboxes
        flash[:error] = "There was a problem with your submission. Please read the agreement and check all checkboxes."
        redirect_to :action => :show_license, :license => @license
        return
      end
    end
    signed_agreements = current_user.meta[:signed_license_agreements] || []
    signed_agreements << @license
    current_user.meta[:signed_license_agreements] = signed_agreements
    current_user.addlog("Signed license agreement '#{@license}'.")
    redirect_to start_page_path
  end

  # Display general information about the CBRAIN project.
  def credits #:nodoc:
    # Nothing to do, just let the view show itself.
  end

  # Displays more detailed info about the CBRAIN project.
  def about_us #:nodoc:
    myself = RemoteResource.current_resource
    info   = myself.info

    @revinfo = { 'Revision'            => info.revision,
                 'Last Changed Author' => info.lc_author,
                 'Last Changed Rev'    => info.lc_rev,
                 'Last Changed Date'   => info.lc_date
               }

  end

  def report #:nodoc:
    table_name      = params[:table_name] || ""
    table_op        = 'count'
    row_type        = params[:row_type]   || ""
    col_type        = params[:col_type]   || ""
    submit          = extract_params_key([ :generate, :refresh, :flip ], "look")
    date_filtering = params[:date_range] || {}

    if submit == :flip
      params[:row_type] = col_type
      params[:col_type] = row_type
      row_type, col_type = col_type, row_type
      submit = :refresh
    end

    if table_name =~ /^(\w+)\.(\S+)$/
      table_name = Regexp.last_match[1]
      table_op   = Regexp.last_match[2]   # e.g. "sum(size)" or "combined_file_rep"
    end

    allowed_breakdown = {
       # Table content  => [ [ row or column attributes ],                                [ content_op ] ]
       #--------------     -----------------------------------------------------------
       Userfile         => [ [ :user_id, :group_id, :data_provider_id, :type           ], [ 'count', 'sum(size)', 'sum(num_files)', 'combined_file_rep' ] ],
       CbrainTask       => [ [ :user_id, :group_id, :bourreau_id,      :type, :status  ], [ 'count', 'sum(cluster_workdir_size)',   'combined_task_rep' ] ],
    }
    allowed_breakdown.merge!( {
       RemoteResource   => [ [ :user_id, :group_id,                    :type           ], [ 'count' ] ],
       DataProvider     => [ [ :user_id, :group_id,                    :type           ], [ 'count' ] ],
       Group            => [ [                                         :type, :site_id ], [ 'count' ] ],
       Tool             => [ [ :user_id, :group_id,                    :category       ], [ 'count' ] ],
       ToolConfig       => [ [           :group_id, :bourreau_id,      :tool_id        ], [ 'count' ] ],
       User             => [ [ :type, :site_id, :timezone, :city, :country             ], [ 'count' ] ]
    }) if current_user.has_role?(:site_manager) || current_user.has_role?(:admin_user)

    @model      = allowed_breakdown.keys.detect { |m| m.table_name == table_name }
    model_brk   = allowed_breakdown[@model] || [[],[]]
    @model_atts = model_brk[0] || [] # used by view to limit types of rows and cols ?
    model_ops   = model_brk[1] || [ 'count' ]
    unless model_ops.include?(table_op) && @model_atts.include?(row_type.to_sym) && @model_atts.include?(col_type.to_sym) && row_type != col_type
      @table_ok = false
      return # with false value for @table_ok
    end

    #date_filtering verification
    error_mess = check_filter_date(date_filtering["date_attribute"], date_filtering["absolute_or_relative_from"], date_filtering["absolute_or_relative_to"],
                                   date_filtering["absolute_from"], date_filtering["absolute_to"], date_filtering["relative_from"], date_filtering["relative_to"])
    if error_mess.present?
      flash.now[:error] = "#{error_mess}"
      return
    end

    return unless submit == :generate || submit == :refresh

    @table_ok = true

    # Compute access restriction to content
    if @model.respond_to?(:find_all_accessible_by_user)
       table_content_scope = @model.find_all_accessible_by_user(current_user)  # no .all here yet! We need to compute more later on
    else
       table_content_scope = @model.where({})
       if ! current_user.has_role?(:admin_user)
         table_content_scope = table_content_scope.where(:user_id  => current_user.available_users.map(&:id))  if @model.columns_hash['user_id']
         table_content_scope = table_content_scope.where(:group_id => current_user.available_groups.map(&:id)) if @model.columns_hash['group_id']
       end
    end

    # Add fixed values
    @filter_fixed = {}
    @model_atts.each do |att|
      val = params[att]
      next unless val.present?
      table_content_scope = table_content_scope.where("#{table_name}.#{att}" => val)
      @filter_fixed[att.to_s] = val
    end

    # Add date filtering
    mode_is_absolute_from = date_filtering["absolute_or_relative_from"] == "absolute" ? true : false
    mode_is_absolute_to   = date_filtering["absolute_or_relative_to"]   == "absolute" ? true : false
    table_content_scope = add_time_condition_to_scope(table_content_scope, table_name, mode_is_absolute_from , mode_is_absolute_to,
        date_filtering["absolute_from"], date_filtering["absolute_to"], date_filtering["relative_from"], date_filtering["relative_to"], date_filtering["date_attribute"])

    # Compute content fetcher
    table_ops = table_op.split(/\W+/).reject { |x| x.blank? }.map { |x| x.to_sym } # 'sum(size)' => [ :sum, :size ]
    #table_content_scope = table_content_scope.where(:id => -999) # for debugging interface appearance -> no entries
    table_content_fetcher = table_content_scope.group( [ "#{table_name}.#{row_type}", "#{table_name}.#{col_type}" ] )
    table_content_fetcher = table_content_fetcher.real_tasks if table_name == 'cbrain_tasks'

    # Fetch one or several reports using the fetcher
    if    table_ops[0] == :combined_file_rep # special fetch of multiple values for file report
      file_sum_size      = table_content_fetcher.sum(:size)
      file_counts        = table_content_fetcher.count
      file_sum_num_files = table_content_fetcher.sum(:num_files)
      file_cnt_size_unk  = table_content_fetcher.where(:size      => nil).count
      @table_content     = merge_vals_as_array(file_sum_size, file_counts, file_sum_num_files, file_cnt_size_unk) # create quadruplets as values
    elsif table_ops[0] == :combined_task_rep # special fetch of multiple values for task report
      task_sum_size      = table_content_fetcher.sum(:cluster_workdir_size)
      task_counts        = table_content_fetcher.count
      task_no_size       = table_content_fetcher.where( :cluster_workdir_size => nil ).where("cluster_workdir IS NOT NULL").count
      @table_content     = merge_vals_as_array(task_sum_size, task_counts, task_no_size) # create triplets
    else
      generic_count  = table_content_fetcher.send(*table_ops)
      @table_content = merge_vals_as_array(generic_count) # create singletons
    end

    # Present content for view
    table_keys = @table_content.keys
    raw_table_row_values = table_keys.collect { |pair| pair[0] }.map { |x| x.presence }.uniq
    raw_table_col_values = table_keys.collect { |pair| pair[1] }.map { |x| x.presence }.uniq
    @table_row_values = raw_table_row_values.compact.sort # sorted non-nil values ; TODO: sort values better?
    @table_col_values = raw_table_col_values.compact.sort # sorted non-nil values ; TODO: sort values better?
    @table_row_values.unshift(nil) if raw_table_row_values.size > @table_row_values.size # reinsert nil if needed
    @table_col_values.unshift(nil) if raw_table_col_values.size > @table_col_values.size # reinsert nil if needed
    @table_row_values.reject! { |x| x == 0 } if row_type =~ /_id$/ # remove 0 values for IDs
    @table_col_values.reject! { |x| x == 0 } if col_type =~ /_id$/ # remove 0 values for IDs

    # For making filter links inside the table
    @filter_model      = @model.to_s.pluralize.underscore
    @filter_model      = "tasks" if @filter_model == 'cbrain_tasks'
    @filter_row_key    = row_type
    @filter_col_key    = col_type
    @filter_show_proc  = (table_op =~ /sum.*size/) ? (Proc.new { |vector| colored_pretty_size(vector[0]) }) : nil
  end

  # This action searches among all sorts of models for IDs or strings,
  # and reports links to the matches found.
  def search
    @search  = params[:search]
    @limit   = 20 # used by interface only

    @results = @search.present? ? ModelsReport.search_for_token(@search, current_user) : {}
  end

  private

  def merge_vals_as_array(*sub_reports) #:nodoc:
    merged_report = {}
    all_keys = []
    sub_reports.each { |rep| all_keys += rep.keys }
    all_keys.each do |key| # key is always a pair for a 2D table
      newkey = [ key[0].presence, key[1].presence ] # simplify key space so that blanks in any component of key become nils
      newval = Array.new(sub_reports.size,0) #  [ 0, 0, 0 ... ] for n reports
      sub_reports.each_with_index do |subrep,i|
        next unless subrep.has_key?(key)
        newval[i] += subrep[key] # should always be a adding a count, which can be zero
      end
      merged_report[newkey] = newval  # the key is cleaned of blanks, the newval is a sum of counts in each report
    end
    merged_report
  end

  def colorize_logs(data) #:nodoc:
    data = ERB::Util.html_escape(data)

    # data.gsub!(/\e\[[\d;]+m/, "") # now done when fetching the raw log, with perl (see above)

    data.gsub!(/^Started.+/)                    { |m| "<span class=\"log_started\">#{m}</span>" }
    data.gsub!(/  Parameters: .+/)              { |m| "<span class=\"log_parameters\">#{m}</span>" }
    data.gsub!(/  Processing by .+/)            { |m| "<span class=\"log_processing\">#{m}</span>" }
    data.gsub!(/^Completed.* in \d{1,3}ms/)     { |m| "<span class=\"log_completed_fast\">#{m}</span>" }
    data.gsub!(/^Completed.* in [1-4]\d\d\dms/) { |m| "<span class=\"log_completed_slow\">#{m}</span>" }
    data.gsub!(/^Completed.* in [5-9]\d\d\dms/) { |m| "<span class=\"log_completed_very_slow\">#{m}</span>" }
    data.gsub!(/^Completed.* in \d+\d\d\d\dms/) { |m| "<span class=\"log_completed_atrociously_slow\">#{m}</span>" }
    data.gsub!(/^User: \S+/)                    { |m| "<span class=\"log_user\">#{m}</span>" }
    data.gsub!(/ using \S+/)                    { |m| "<span class=\"log_browser\">#{m}</span>" }

    alt = :_1
    data.gsub!(/  (SQL|CACHE|[A-Za-z\:]+ Load) \(\d+.\d+ms\)/) do |m|
      alt = (alt == :_1) ? :_2 : :_1
      "<span class=\"log_alternating#{alt}\">#{m}</span>"
    end

    data
  end

end
