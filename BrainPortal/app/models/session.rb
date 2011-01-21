
#
# CBRAIN Project
#
# Model for the current session.
#
# Original author: Tarek Sherif
#
# $Id$
#

#Model represeting the current session. The current session object can 
#be accessed using the <b><tt>current_session</tt></b> method of the ApplicationController
#class.
#
#This model is meant to act as a wrapper around the session hash.
#It takes care of updating the values of and performing any logic related 
#to the following attributes of the current session (mainly related
#to the Userfile index page):
#* currently active filters.
#* whether or not pagination is active.
#* current ordering of the Userfile index.
#* whether to view current user's files or all files on the system (*admin* only).
#
#Session attributes can be accessed by calling methods with the attribute name.
#*Example*: calling +current_session+.+current_filters+ will access <tt>session[:current_filters]</tt>
#
#*Note*: this is not a database-backed model.
class Session

  Revision_info="$Id$"
  
  def initialize(session, params) #:nodoc:
    @session = session
    if @session[:userfiles_sort_order] == "userfiles.lft"
      @session[:userfiles_sort_order] = nil
    end
    
    @session[:userfiles_basic_filters] ||= []
    @session[:userfiles_tag_filters] ||= []
    @session[:userfiles_custom_filters] ||= []
    @session[:userfiles_sort_order] ||= 'userfiles.name'
    @session[:userfiles_tree_sort] ||= 'on'
    @session[:userfiles_pagination] ||= 'on'
    @session[:userfiles_details] ||= 'off'
    
    controller = params[:controller]
    @session[controller.to_sym] ||= {}
    @session[controller.to_sym]["filters"] ||= {}
    @session[controller.to_sym]["sort"] ||= {}
  end
  
  #Mark this session as active in the database.
  def activate
    @session.model.update_attributes!(:user_id => @session[:user_id], :active => true)
  end
  
  #Mark this session as inactive in the database.
  def deactivate
    @session.model.update_attributes!(:active => false)
  end
  
  #Returns the list of currently active users on the system.
  def self.active_users(options = {})
    active_sessions = session_class.find(:all, :conditions =>
      ["sessions.active = TRUE AND sessions.user_id IS NOT NULL AND sessions.updated_at > ?", 10.minutes.ago]
    )
    user_ids = active_sessions.map &:user_id
    scope = User.scoped(options)
    scope.scoped( :conditions => { :id => user_ids } )
  end
  
  def self.count(options = {}) #:nodoc:
    scope = session_class.scoped({})
    scope.count
  end
  
  def self.session_class #:nodoc:
    CGI::Session::ActiveRecordStore::Session
  end

  def self.all #:nodoc:
    self.session_class.all
  end
  
  def self.recent_activity(n = 10, options = {}) #:nodoc:
    scope = User.scoped(options)
    last_sessions = session_class.find(:all, :conditions => "sessions.user_id IS NOT NULL", :order  => "sessions.updated_at DESC")
    entries = []
    
    last_sessions.each do |sess|
      break if entries.size >= n
      user = User.find(sess.user_id)
      entries << {
        :user           => user,
        :active         => sess.active?,
        :last_access    => sess.updated_at,
        :remote_ip      => sess.data[:guessed_remote_ip],    # can be nil
        :remote_host    => sess.data[:guessed_remote_host],  # can be nil
        :raw_user_agent => sess.data[:raw_user_agent],       # can be nil
      }
    end
    
    entries
  end

  # Erase most of the entries in the data
  # section of the session; this is used when the
  # user logs out. Some elements are kept
  # for tracking no matter what, like the
  # :guessed_remote_host and the :raw_user_agent
  def clear_data!
    @session.data.each do |k,v|
      next if [ :guessed_remote_host, :raw_user_agent ].include?(k)
      @session[k] = nil
    end
  end
  
  #Update attributes of the session object based on the incoming request parameters
  #contained in the +params+ hash.
  def update(params)
    controller = params[:controller]

    #TODO: It would be nice if userfiles used the generalized system.
    filter = Userfile.get_filter_name(params[:userfiles_search_type], params[:userfiles_search_term])
    if params[:userfiles_search_type] == 'unfilter'
      @session[:userfiles_format_filters] = nil
      @session[:userfiles_basic_filters] = []
      @session[:userfiles_tag_filters] = []
      @session[:userfiles_custom_filters] = []
    else
      @session[:userfiles_basic_filters] |= [filter] unless filter.blank?
      @session[:userfiles_format_filters] = params[:userfiles_format_filter] unless params[:userfiles_format_filter].blank?
      @session[:userfiles_tag_filters] |= [params[:userfiles_tag_filter]] unless params[:userfiles_tag_filter].blank?
      @session[:userfiles_custom_filters] |= [UserfileCustomFilter.find(params[:userfiles_custom_filter]).name] unless params[:userfiles_custom_filter].blank?
      @session[:userfiles_basic_filters].delete params[:userfiles_remove_basic_filter] if params[:userfiles_remove_basic_filter]
      @session[:userfiles_format_filters] = nil if params[:userfiles_remove_format_filter]
      @session[:userfiles_custom_filters].delete params[:userfiles_remove_custom_filter] if params[:userfiles_remove_custom_filter]
      @session[:userfiles_tag_filters].delete params[:userfiles_remove_tag_filter] if params[:userfiles_remove_tag_filter]
    end
        
    if params[:userfiles_view_all] && (User.find(@session[:user_id]).has_role?(:admin) || User.find(@session[:user_id]).has_role?(:site_manager))
      @session[:userfiles_view_all] = params[:userfiles_view_all]
    end
    
    if params[:userfiles_sort_order] && !params[:page]
      @session[:userfiles_sort_order] = sanitize_sort_order(params[:userfiles_sort_order])
      @session[:userfiles_sort_dir] = sanitize_sort_dir(params[:userfiles_sort_dir])
    end
    
    if params[:userfiles_tree_sort]
      @session[:userfiles_tree_sort] = params[:userfiles_tree_sort]
    end
    
    if params[:userfiles_pagination]
      @session[:userfiles_pagination] = params[:userfiles_pagination]
    end
    
    if params[:userfiles_details]
      @session[:userfiles_details] = params[:userfiles_details]
    end
     
    if params[controller]
      if params[controller]["filter_off"]
        @session[controller.to_sym]["filters"] = {}
      end
      if params[controller]["remove_filter"]
        @session[controller.to_sym]["filters"].delete(params[controller]["remove_filter"])
      end
      params[controller].each do |k, v|
        if @session[controller.to_sym][k].respond_to? :merge!
          @session[controller.to_sym][k].merge!(sanitize_params(k, params[controller][k]) || {})
        else
          @session[controller.to_sym][k] = sanitize_params(k, params[controller][k])
        end
      end
    end
  end
  
  #Is pagination of the Userfile index currently active?
  def paginate?
    @session[:userfiles_pagination] == 'on'
  end
  
  #Is the current *admin* user viewing all files on the system (or only his/her own)?
  def view_all?
    @session[:userfiles_view_all] == 'on' && (User.find(@session[:user_id]).has_role?(:admin) || User.find(@session[:user_id]).has_role?(:site_manager))
  end
  
  #Returns the params saved for +controller+.
  def params_for(controller)
    @session[controller.to_sym]
  end
  
  #Hash-like access to session attributes.
  def [](key)
    @session[key]
  end
  
  #Hash-like assignment to session attributes.
  def []=(key, value)
    if key == :user_id
      @session.model.update_attributes!(:user_id => value)
    end
    @session[key] = value
  end
  
  #The method_missing method has been redefined to allow for simplified access to session parameters.
  #
  #*Example*: calling +current_session+.+current_filters+ will access <tt>session[:current_filters]</tt>
  def method_missing(key, *args)
    @session[key.to_sym]
  end
  
  private
  
  def sanitize_params(k, param) #:nodoc:
    key = k.to_sym
    
    if key == :sort
      param["order"] = sanitize_sort_order(param["order"])
      param["dir"] = sanitize_sort_dir(param["dir"])
    end
    
    param
  end
  
  def sanitize_sort_order(order) #:nodoc:
    table, column = order.strip.split(".")
    table = table.tableize
    
    unless ActiveRecord::Base.connection.tables.include?(table)
      cb_error "Invalid sort table: #{table}."
    end
    
    klass = Class.const_get table.classify
    
    unless klass.column_names.include?(column) ||
        (klass.respond_to?(:pseudo_sort_columns) && klass.pseudo_sort_columns.include?(column))
      cb_error "Invalid sort column: #{table}.#{column}"
    end
    
    "#{table}.#{column}"
  end
  
  def sanitize_sort_dir(dir) #:nodoc:
    if dir.to_s.strip.upcase == "DESC"
      "DESC"
    else
      ""
    end
  end
  
end
