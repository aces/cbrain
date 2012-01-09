#Helpers for creating filter links.
module FilterHelper
  
  Revision_info=CbrainFileRevision[__FILE__]
  
  # Add to currently active filters. Options include:
  # [:parameter] which filter parameter to adjust (default to :filter_hash).
  # [:value]     the value to update it with.
  def filter_add_link(name, options = {})
    filter_param = options.delete(:parameter) || :filter_hash
    values       = options.delete(:value)   if options.has_key?(:value) #Value and filters synonymous but filters takes priority
    values       = options.delete(:filters) if options.has_key?(:filters)
    if values.respond_to?(:merge)
      params_hash  = values.merge :update_filter => filter_param
    else
      params_hash  = {filter_param => values}.merge :update_filter => true
    end
    options[:pretty] = true
    build_filter_link name, params_hash, options
  end
  
  # Remove a filter from those currently active. +key+ is the filter 
  # attribute to be adjusted.
  # 
  # Options:
  # [:parameter] which filter to adjust (defaults to :filter_hash). 
  def filter_remove_link(name, key, options = {})
    filter_param = options.delete(:parameter) || :filter_hash
    params_hash = {:remove => {filter_param => key}}
    build_filter_link name, params_hash, options
  end
  
  # Clear a filter. The option :clear_params can be used in two ways.
  # The first is to set it to the name of a know filter. The second is to
  # set the value to clear_<x>, where +x+ is the prefix of a 'type' of filter.
  # In the latter case, all filters with the given prefix will be cleared.
  def filter_clear_link(name, options = {})
    cleared_params = options.delete(:clear_params) || :clear_filter
    if !cleared_params.is_a?(Array) && cleared_params.to_s =~ /^clear_/
      params_hash = {cleared_params => true}  
    else
      params_hash = {:clear_all  => cleared_params}
    end
    options[:pretty] = true
    build_filter_link name, params_hash, options
  end
  
  # Combines the functionality of filter_add_link and filter_clear_link. 
  # A filter is cleared and than a new value is added to the the empty filter.
  def filter_reset_link(name, options = {})
    filter_param = options.delete(:parameter) || :filter_hash
    values       = options.delete(:value)   if options.has_key?(:value) #Value and filters synonymous but filters takes priority
    values       = options.delete(:filters) if options.has_key?(:filters)
    if values.respond_to?(:merge)
      params_hash  = values.merge :update_filter => filter_param
    else
      params_hash  = {filter_param => values}.merge :update_filter => true
    end
    cleared_params = options.delete(:clear_params) || :clear_filter
    if !cleared_params.is_a?(Array) && cleared_params.to_s =~ /^clear_/
      params_hash.merge! cleared_params => true
    else
      params_hash.merge! :clear_all  => cleared_params
    end
    options[:pretty] = true
    build_filter_link name, params_hash, options
  end
  
  def build_filter_link(name, params_hash, options = {}) #:nodoc:
    controller   = options.delete(:controller) || params[:controller]
    if options.has_key?(:ajax) 
      ajax         = options.delete(:ajax)
    else
      ajax         = true
    end
    unless options.delete(:pretty)
      params_hash = {controller.to_sym  => params_hash}
    end
    url = {:controller => controller, :action => :index}.merge params_hash
    if ajax
      options[:datatype] ||= :script
      ajax_link name, url, options
    else
      link_to h(name.to_s), url, options
    end
  end
  
  #Will check for associations to display them properly.
  def display_filter(model, key, value, methods = {})
    exceptions = {
      "group" => "project",
      "bourreau"  => "server"
    }
    
    klass = Class.const_get model.to_s.classify
    association = klass.reflect_on_all_associations(:belongs_to).find { |a| a.primary_key_name == key.to_s  }
    if association
      association_key   = association.primary_key_name
      association_name  = association.name.to_s
      association_class = Class.const_get association.class_name
      name_method = methods[association_key.to_sym] || methods[association_name.to_sym] || :name
      object = association_class.find_by_id(value)
      if exceptions[association_name]
        association_name = exceptions[association_name]
      end
      if object
        "#{association_name.humanize}: #{object.send(name_method)}"
      else
        "#{key.to_s.humanize}: #{value}"
      end
    else
      "#{key.to_s.humanize}: #{value}"
    end
  end
end
