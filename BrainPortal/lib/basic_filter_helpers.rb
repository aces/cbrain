# Helpers to create filter lists for index tables 
# (see index_table_helper.rb).
module BasicFilterHelpers
  
  def self.included(includer) #:nodoc:
    includer.class_eval do
      helper_method :current_session,   :current_project
      helper_method :basic_filters_for, :association_filters_for
      before_filter :update_filters
    end
  end

  #Returns the current session as a CbrainSession object.
  def current_session
    @cbrain_session ||= CbrainSession.new(session, params, request.env['rack.session.record'] )
  end
  
  #Returns currently active project.
  def current_project
    return nil unless current_session[:active_group_id]
    
    if !@current_project || @current_project.id.to_i != current_session[:active_group_id].to_i
      @current_project = Group.find_by_id(current_session[:active_group_id])
      current_session[:active_group_id] = nil if @current_project.nil?
    end
    
    @current_project
  end
  
  # Easy and safe filtering based on individual attributes or named scopes.
  # Simply adding <att>=<val> to a URL on an index page that uses this method
  # will automatically filter as long as <att> is a valid attribute or named
  # scope.
  def base_filtered_scope(filtered_scope = resource_class.scoped({}), do_sort = true)
    @filter_params["filter_hash"].each do |att, val|
      if filtered_scope.scopes[att.to_sym] && att.to_sym != :scoped
        filtered_scope = filtered_scope.send(att, *val)
      elsif table_column?(resource_class, att)
        filtered_scope = filtered_scope.scoped(:conditions => {att => val})
      else
        @filter_params["filter_hash"].delete att
      end
    end
    if do_sort && @filter_params["sort_hash"] && @filter_params["sort_hash"]["order"] && table_column?(*@filter_params["sort_hash"]["order"].split("."))
      filtered_scope = filtered_scope.order("#{@filter_params["sort_hash"]["order"]} #{@filter_params["sort_hash"]["dir"]}")
    end
    filtered_scope
  end
  
  def always_activate_session
    session[:cbrain_toggle] = (1 - (session[:cbrain_toggle] || 0))
    true
  end
  
  # Convenience method to determine wether a given model has the provided attribute.
  # Note: mainly for security reasons; this allows easy sanitization of parameters related
  # to attributes.
  def table_column?(model, attribute)
    column = attribute
    klass = Class.const_get model.to_s.classify
    
    klass.columns_hash[column]
  rescue
    false   
  end
  
  #Create filtered array to be used by TableBuilder for
  #basic attribute filters.
  def basic_filters_for(scope, tab, col, &block)
    table         = tab.to_s.underscore.pluralize
    column        = col.to_sym
    pretty_method = (column == :type) ? :pretty_type : column
    formatter     = block || Proc.new { |text| text }

    scope.select( "#{table}.#{column}, COUNT(#{table}.#{column}) as count" ).
          where( "#{table}.#{column} IS NOT NULL" ).
          group("#{table}.#{column}").
          order("#{table}.#{column}").
          reject { |obj| obj.send(column).blank? }.
          map { |obj| ["#{formatter.call(obj.send(pretty_method))} (#{obj.count})", :filters => {column => obj.send(column)}]}
  end
  
  #Create filtered array to be used by TableBuilder for
  #basic association filters.
  def association_filters_for(scope, tab, assoc, options = {}, &block)
    table       = tab.to_s.underscore.pluralize
    association = assoc.to_s.underscore.singularize
    assoc_table = options[:association_table] || association.pluralize
    name_method = options[:name_method] || "name"
    foreign_key = options[:foreign_key] || "#{association}_id"
    formatter   = block || Proc.new { |text| text }
    
    scope.select( "#{table}.#{foreign_key}, #{assoc_table}.#{name_method} as #{association}_#{name_method}, COUNT(#{table}.#{foreign_key}) as count" ).
          joins(association.to_sym).
          order("#{assoc_table}.#{name_method}").
          group("#{table}.#{foreign_key}").
          all.
          map { |obj| ["#{formatter.call(obj.send("#{association}_#{name_method}"))} (#{obj.count})", :filters => {foreign_key => obj.send(foreign_key)}] }
  end
  
  # Set up the current_session variable. Mainly used to set up the filter hash to be
  # used by index actions.
  def update_filters
    current_controller = params[:controller]
    params[current_controller] ||= {}
    clear_params       = params.keys.select{ |k| k.to_s =~ /^clear_/}
    clear_param_key    = clear_params.first
    clear_param_value  = params[clear_param_key]
    if clear_param_key
      params[current_controller][clear_param_key.to_s] = clear_param_value
    end
    clear_params.each { |p| params.delete p.to_s }
    if params[:update_filter]
      update_filter      = params[:update_filter].to_s
      parameters = request.query_parameters.clone
      parameters.delete "update_filter"
      if update_filter =~ /_hash$/
        params[current_controller][update_filter] = parameters
      else
        params[current_controller] = parameters
      end
      params.delete "update_filter"
      parameters.keys.each { |p|  params.delete p}
    end
    current_session.update(params)

    @filter_params = current_session.params_for(params[:controller])
    validate_pagination_values
  end

  ########################################################################
  # CBRAIN Helper for pagination
  ########################################################################

  # This prevents users to give wrong number page for example -1 or 999_999_999_9999_999
  # and limit the per_page variable in order to be in a certain range.
  # If the values for @per_page or @current_page are already set, you can
  # use this method to sanitize them.
  def validate_pagination_values #:nodoc:
    # Validate per_page
    @per_page     ||= @filter_params["per_page"]
    @per_page       = @per_page.to_i
    @per_page       = 25  if @per_page < 25
    @per_page       = 500 if @per_page > 500

    # Validate page
    @current_page ||= params[:page]
    @current_page   = @current_page.to_i
    @current_page   = 1      if @current_page < 1
    @current_page   = 99_999 if @current_page > 99_999
  end

end
