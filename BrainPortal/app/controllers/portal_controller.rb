
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

#Controller for the entry point into the system.
class PortalController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__]

  include DateRangeRestriction

  before_filter :login_required, :except => [ :credits, :about_us, :welcome ]  # welcome is here so that the redirect to the login page doesn't show the error message
  before_filter :admin_role_required, :only => :portal_log
  
  #Display a user's home page with information about their account.
  def welcome #:nodoc:
    unless current_user
      redirect_to login_path 
      return
    end
    
    @num_files              = current_user.userfiles.size
    @groups                 = current_user.has_role?(:admin) ? current_user.groups.order(:name) : current_user.available_groups.order(:name)
    @default_data_provider  = DataProvider.find_by_id(current_user.meta["pref_data_provider_id"])
    @default_bourreau       = Bourreau.find_by_id(current_user.meta["pref_bourreau_id"])     
        
    if current_user.has_role? :admin
      @active_users = CbrainSession.active_users
      @active_users.unshift(current_user) unless @active_users.include?(current_user)
      if request.post?
        unless params[:session_clear].blank?
          CbrainSession.session_class.where(["updated_at < ?", params[:session_clear].to_i.seconds.ago]).delete_all
        end
        if params[:lock_portal] == "lock"
          BrainPortal.current_resource.lock!
          message = params[:message] || ""
          message = "" if message =~ /\(lock message\)/ # the default string
          BrainPortal.current_resource.meta[:portal_lock_message] = message
          flash.now[:notice] = "This portal has been locked."
        elsif params[:lock_portal] == "unlock"
          BrainPortal.current_resource.unlock!
          flash.now[:notice] = "This portal has been unlocked."
          flash.now[:error] = ""        
        end
      end
    #elsif current_user.has_role? :site_manager
    #  @active_users = CbrainSession.active_users.where( :site_id  => current_user.site_id )
    #  @active_users.unshift(current_user) unless @active_users.include?(current_user)
    end
    
    bourreau_ids = Bourreau.find_all_accessible_by_user(current_user).all.collect(&:id)
    @tasks       = CbrainTask.where( :user_id => current_user.id, :bourreau_id => bourreau_ids,
                   :status => CbrainTask::FAILED_STATUS + CbrainTask::COMPLETED_STATUS + CbrainTask::RUNNING_STATUS).order( "updated_at DESC" ).limit(15).all
  end
  
  def portal_log
    num_lines = (params[:num_lines] || 5000).to_i
    num_lines = 1000 if num_lines < 1000
    num_lines = 20_000 if num_lines > 20_000
    log =  IO.popen("tail -#{num_lines} #{Rails.configuration.paths.log.first}", "r").read
    render :text => "<pre>#{ascii_color_to_html(log)}</pre>"
  end
  
  def show_license
    @license = params[:license].gsub(/[^\w-]+/, "")
  end
   
  def sign_license
    @license = params[:license]
    unless params[:commit] == "I Agree"
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
    redirect_to home_path
  end
  
  #Display general information about the CBRAIN project.
  def credits #:nodoc:
    # Nothing to do, just let the view show itself.
  end
  
  #Displays more detailed info about the CBRAIN project.
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
    submit          = params[:commit]     || "look"
    date_filtration = params[:date_range]       || {}

    if table_name =~ /^(\w+)\.(\S+)$/
      table_name = Regexp.last_match[1]
      table_op   = Regexp.last_match[2]   # e.g. "sum(size)"
    end

    allowed_breakdown = {
       # Table content  => [ [ row or column attributes ],                                [ content_op ] ]
       #--------------     -----------------------------------------------------------
       Userfile         => [ [ :user_id, :group_id, :data_provider_id, :type           ], [ 'count', 'sum(size)', 'sum(num_files)' ] ],
       CbrainTask       => [ [ :user_id, :group_id, :bourreau_id,      :type, :status  ], [ 'count', 'sum(cluster_workdir_size)'   ] ],
    }
    allowed_breakdown.merge!( {
       RemoteResource   => [ [ :user_id, :group_id,                    :type           ], [ 'count' ] ],
       DataProvider     => [ [ :user_id, :group_id,                    :type           ], [ 'count' ] ],
       Group            => [ [                                         :type, :site_id ], [ 'count' ] ],
       Tool             => [ [ :user_id, :group_id,                    :category       ], [ 'count' ] ],
       ToolConfig       => [ [           :group_id, :bourreau_id,      :tool_id        ], [ 'count' ] ],
       User             => [ [ :role, :site_id, :timezone, :city, :country             ], [ 'count' ] ]
    }) if current_user.has_role?(:admin) ||  current_user.has_role?(:site_admin)

    @model      = allowed_breakdown.keys.detect { |m| m.table_name == table_name }
    model_brk   = allowed_breakdown[@model] || [[],[]]
    @model_atts = model_brk[0] || [] # used by view to limit types of rows and cols ?
    model_ops   = model_brk[1] || [ 'count' ]
    unless model_ops.include?(table_op) && @model_atts.include?(row_type.to_sym) && @model_atts.include?(col_type.to_sym) && row_type != col_type
      @table_ok = false
      return # with false value for @table_ok
    end

    #date_filtration verification
    error_mess = check_filter_date(date_filtration["date_attribute"], date_filtration["absolute_or_relative_from"], date_filtration["absolute_or_relative_to"],
                                   date_filtration["absolute_from"], date_filtration["absolute_to"], date_filtration["relative_from"], date_filtration["relative_to"])
    if error_mess.present?
      flash[:error] = "#{error_mess}"
      return
    end
    
    return unless submit =~ /generate|refresh/i

    @table_ok = true

    # Compute access restriction to content
    if @model.respond_to?(:find_all_accessible_by_user)
       @table_content = @model.find_all_accessible_by_user(current_user)  # no .all here yet! We need to compute more later on
    else
       @table_content = @model.where({})
       if ! current_user.has_role?(:admin)
         @table_content = @table_content.where(:user_id  => current_user.available_users.map(&:id))  if @model.columns_hash['user_id']
         @table_content = @table_content.where(:group_id => current_user.available_groups.map(&:id)) if @model.columns_hash['group_id']
       end
    end

    # Add fixed values
    @model_atts.each do |att|
      val = params[att]
      next unless val.present?
      @table_content = @table_content.where(att => val)
    end

    # Add date filtration
    mode_is_absolute_from = date_filtration["absolute_or_relative_from"] == "absolute" ? true : false
    mode_is_absolute_to   = date_filtration["absolute_or_relative_to"]   == "absolute" ? true : false
    @table_content = add_condition_to_scope(@table_content, table_name, mode_is_absolute_from , mode_is_absolute_to,
        date_filtration["absolute_from"], date_filtration["absolute_to"], date_filtration["relative_from"], date_filtration["relative_to"], date_filtration["date_attribute"])

    # Compute content
    table_ops = table_op.split(/\W+/).reject { |x| x.blank? }.map { |x| x.to_sym } # 'sum(size)' => [ :sum, :size ]
    #@table_content = @table_content.where(:user_id => 999) # for debug -> no entries
    @table_content = @table_content.group( [ row_type, col_type ] ).send(*table_ops)

    # Present content for view
    table_keys = @table_content.keys
    @table_row_values = table_keys.collect { |pair| pair[0] }.compact.sort.uniq
    @table_col_values = table_keys.collect { |pair| pair[1] }.compact.sort.uniq
    @table_row_values.reject! { |x| x == 0 } if row_type =~ /_id$/
    @table_col_values.reject! { |x| x == 0 } if col_type =~ /_id$/
    # TODO: sort values better?

    # For making filter links inside the table
    @filter_model      = @model.to_s.pluralize.underscore
    @filter_model      = "tasks" if @filter_model == 'cbrain_tasks'
    @filter_row_key    = row_type
    @filter_col_key    = col_type
    @filter_show_proc  = (table_op =~ /sum.*size/) ? (Proc.new { |x| colored_pretty_size(x) }) : nil
  end
  
  private
  
  def ascii_color_to_html(data)
    colors = { 
              30 => :black,
              31 => :red,
              32 => :green,
              33 => :yellow,
              34 => :blue,
              35 => :magenta,
              36 => :cyan,
              37 => :white,
            }
    color_keys = colors.keys
    data.gsub!(/\e\[\d+m.*\e\[0m/) do |m|
      color_match = false
      color = nil
      color_keys.each do |k|
        if m =~ /\e\[#{k}m/
          color_match = true
          color = colors[k]
        end
      end
      result = m
      result.gsub!(/\e\[\d+m/, "")
      result.gsub!(/\e\[0m/, "")
      result = "<span style=\"color:#{color}\">#{result}</span>" if color_match
      result
    end

    data 
  end

end
