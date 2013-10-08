
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

# Helpers to create filter lists for index tables 
# (see index_table_helper.rb).
module BasicFilterHelpers

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.included(includer) #:nodoc:
    includer.class_eval do
      helper_method :basic_filters_for, :association_filters_for
      # To improve performance update_filters should be called only in certain case in:
      before_filter :update_filters,             :only => [
          :index,             # for all controllers
          :filter_proxy,      # in application controller
          :row_data,          # in bourreaux controller
          :browse, :register, # in data_providers controller
          :operation,         # in tasks controller
          :manage_persistent, # in userfiles controller
          ]
      before_filter :validate_pagination_values, :only => [ :index, :filter_proxy ]
    end
  end

  # Easy and safe filtering based on individual attributes or named scopes.
  # Simply adding <att>=<val> to a URL on an index page that uses this method
  # will automatically filter as long as <att> is a valid attribute or named
  # scope.
  def base_filtered_scope(filtered_scope = resource_class.scoped({}))
    @filter_params["filter_hash"].each do |att, val|
      if filtered_scope.cb_scopes[att.to_sym] && att.to_sym != :scoped
        filtered_scope = filtered_scope.send(att, *val)
      elsif table_column?(resource_class, att)
        filtered_scope = filtered_scope.scoped(:conditions => {att => val})
      else
        @filter_params["filter_hash"].delete att
      end
    end
    filtered_scope
  end
  
  #Apply currently active sort parameters to a scope
  def base_sorted_scope(sorted_scope = resource_class.scoped)
    if @filter_params["sort_hash"] && @filter_params["sort_hash"]["order"] && table_column?(*@filter_params["sort_hash"]["order"].split("."))
      sorted_scope = sorted_scope.order("#{@filter_params["sort_hash"]["order"]} #{@filter_params["sort_hash"]["dir"]}")
    end
    sorted_scope
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
  def basic_filters_for(filtered_scope, header_scope, tab, col, &formatter)
    table         = tab.to_s.underscore.pluralize
    column        = col.to_sym
    column_object = ActiveRecord::Base.connection.columns(table).find { |c| c.name == column.to_s }
    table_column  = "#{table}.#{column}"

    filt_counts = filtered_scope.undo_where(table_column).group(table_column).count

    header_scope.
      where( "#{table_column} IS NOT NULL" ).
      group( table_column ).
      order( table_column ).
      raw_rows(table_column, "COUNT(#{table_column})").
      reject { |pair| pair[0].blank? }.
      map do |pair|
        raw_name, count = pair
        name            = column_object.type_cast(raw_name)
        pretty_name     = column == :type ? name.constantize.pretty_type : name
        formatted_name  = formatter ? formatter.call(pretty_name) : pretty_name
        filt_count      = filt_counts[name].to_i

        [ "#{formatted_name} (#{filt_count}/#{count})", 
            :filters => { column => raw_name },
            :class   => filt_count == 0 ? "filter_zero" : nil
        ]
      end
  end
  
  #Create filtered array to be used by TableBuilder for
  #basic association filters.
  def association_filters_for(filtered_scope, header_scope, tab, assoc, options = {}, &formatter)
    table       = tab.to_s.underscore.pluralize
    association = assoc.to_s.underscore.singularize
    assoc_table = options[:association_table] || association.pluralize
    name_method = options[:name_method] || "name"
    foreign_key = options[:foreign_key] || "#{association}_id"

    table_fkey  = "#{table}.#{foreign_key}"
    assoc_name  = "#{assoc_table}.#{name_method}"
    
    filt_counts = filtered_scope.undo_where(table_fkey).joins(association.to_sym).group(table_fkey).count
    
    header_scope.
      joins(association.to_sym).
      order(assoc_name).
      group(table_fkey).
      raw_rows( table_fkey, assoc_name, "COUNT(#{table_fkey})").
      map do |triplet|
        fkey, name, count = triplet
        filt_count        = filt_counts[fkey].to_i
        formatted_name    = formatter ? formatter.call(name) : name

        [ "#{formatted_name} (#{filt_count}/#{count})",
            :filters => { foreign_key => fkey },
            :class   => filt_count == 0 ? "filter_zero" : nil
        ]
      end
  end
  
  # Set up the current_session variable. Mainly used to set up the filter hash to be
  # used by index actions.
  def update_filters
    current_controller = params[:proxy_destination_controller] || params[:controller]
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
      parameters.delete "proxy_destination_controller"
      parameters.delete "proxy_destination_action"
      if update_filter =~ /_hash$/
        params[current_controller][update_filter] = parameters
      else
        params[current_controller] = parameters
      end
      params.delete "update_filter"
      parameters.keys.each { |p|  params.delete p}
    end
    current_session.update(params)

    @filter_params = current_session.params_for(params[:proxy_destination_controller] || params[:controller])
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

