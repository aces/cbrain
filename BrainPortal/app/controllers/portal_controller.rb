
#
# CBRAIN Project
#
# Contoller for the entrypoint to cbrain
#
# Original author: Tarek Sherif
#
# $Id$
#

#Controller for the entry point into the system.
class PortalController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__]

  before_filter :login_required, :except => [ :credits, :about_us, :welcome ]  # welcome is here so that the redirect to the login page doesn't show the error message
  
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
    table_name = params[:table_name] || ""
    table_op   = 'count'
    row_type   = params[:row_type]   || ""
    col_type   = params[:col_type]   || ""
    submit     = params[:commit]     || "look"

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

    @model       = allowed_breakdown.keys.detect { |m| m.table_name == table_name }
    model_brk   = allowed_breakdown[@model] || [[],[]]
    @model_atts = model_brk[0] || [] # used by view to limit types of rows and cols ?
    model_ops   = model_brk[1] || [ 'count' ]
    unless model_ops.include?(table_op) && @model_atts.include?(row_type.to_sym) && @model_atts.include?(col_type.to_sym) && row_type != col_type
      @table_ok = false
      return # with false value for @table_ok
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

end
