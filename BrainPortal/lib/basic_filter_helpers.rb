# Helpers to create filter lists for index tables 
# (see index_table_helper.rb).
module BasicFilterHelpers
  
  def self.included(includer) #:nodoc:
    includer.class_eval do
      helper_method :basic_filters_for, :association_filters_for
    end
  end
  
  #Create filtered array to be used by TableBuilder for
  #basic attribute filters.
  def basic_filters_for(scope, tab, col, &block)
    table     = tab.to_s.underscore.pluralize
    column    = col.to_sym
    formatter = block || Proc.new { |text| text }
    
    scope.select( "#{table}.#{column}, COUNT(#{table}.#{column}) as count" ).
          where( "#{table}.#{column} IS NOT NULL" ).
          group("#{table}.#{column}").
          order("#{table}.#{column}").
          reject { |obj| obj.send(column).blank? }.
          map { |obj|  ["#{formatter.call(obj.send(column))} (#{obj.count})", column => obj.send(column)]}
  end
  
  #Create filtered array to be used by TableBuilder for
  #basic association filters.
  def association_filters_for(scope, tab, assoc, options = {}, &block)
    table       = tab.to_s.underscore.pluralize
    association = assoc.to_s.underscore.singularize
    assoc_table = association.pluralize
    name_method = options[:name_method] || "name"
    foreign_key = options[:foreign_key] || "#{association}_id"
    formatter   = block || Proc.new { |text| text }
    
    scope.select( "#{table}.#{foreign_key}, #{assoc_table}.#{name_method} as #{association}_#{name_method}, COUNT(#{table}.#{foreign_key}) as count" ).
          joins(association.to_sym).
          order("#{assoc_table}.#{name_method}").
          group("#{table}.#{foreign_key}").
          all.
          map { |obj| ["#{formatter.call(obj.send("#{association}_#{name_method}"))} (#{obj.count})", foreign_key => obj.send(foreign_key)] }
  end
  
end