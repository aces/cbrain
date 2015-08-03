
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

# Helper for creating dynamic tables with sorting and filtering capabilities
# over arbitrary object collections. For example;
#   <%
#     dynamic_table(@users) do |t|
#       t.column("Login",     :login)
#       t.column("Full name", :name) { |user| "#{user.first_name} #{user.last_name}" }
#       t.column("Role",      :role, :sort_order => :asc)
#       t.paginate :bottom
#     end
#   %>
# would create a dynamic table for @users with 3 columns (login names, username
# and role) and pagination.
#
# To allow sorting using one of the table's columns, specify the :sortable
# option when invoking +column+:
#   <%
#     dynamic_table(@users) do |t|
#       t.column("Login", :login, :sortable => true)
#     end
#   %>
# Sortable columns have an additional button in their column headers which, when clicked,
# performs a configurable request to allow server-side sorting.
# For further details related to sorting, see the sort_target and sort_order
# options of +dynamic_table+ and +column+
#
# For filtering, specify the :filterable option with a set of :filters:
#   <%
#     dynamic_table(@users) do |t|
#       t.column("Login", :login, :filterable => true, :filters => @login_filters)
#     end
#   %>
# Just like sortable columns, filterable columns have an additional button in
# their headers to trigger a request for server-side filtering. See the filter_target
# and filters options to +dynamic_table+ and +column+ for more details.
#
# Dynamic table public API methods:
# * +dynamic_table+              Create a dynamic table
# * +dynamic_index_table+        Create a index-specific dynamic table
# * +DynamicTable+::+column+     Add a column
# * +DynamicTable+::+row+        Set row attributes
# * +DynamicTable+::+selectable+ Make rows selectable
# * +DynamicTable+::+pagination+ Add pagination
module DynamicTableHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Represents an entire dynamic table. This object is the one given by the API
  # in +dynamic_table+'s block and passed to the view partial for rendering.
  # It contains every aspect of the table to be generated.
  class DynamicTable

    # Table rows. Instances of DynamicTable::Row, each contains a single piece
    # of the collection to create a table for.
    #
    # Internal field; rows are created and managed automatically. Use the
    # +row+ method to modify row attributes.
    attr_accessor :rows

    # Table columns. Instances of DynamicTable::Column, each handles a single
    # field of the collection objects.
    #
    # Internal field; columns are created by using the +column+ method inside
    # +dynamic_table+'s block. Use the arguments to the +column+ method to modify
    # column attributes.
    attr_accessor :columns

    # Hash of extra UI components for the table, such as pagination.
    #
    # Internal field; add UI components using their respective methods.
    # This property is mainly used to render the components themselves.
    attr_accessor :components

    # Template from the templating engine (usually ERB) used to render the table
    # and to access request parameters.
    #
    # Internal field; this attribute is automatically set to the currently
    # evaluated template when calling +dynamic_table+.
    attr_accessor :template

    # HTML attributes for the table. Unlike row and cell attributes,
    # the table's attributes cannot be specified using a callback and are
    # thus defined at table creation.
    #
    # Internal field; table attributes are set directly when calling
    # +dynamic_table+.
    attr_accessor :attributes

    # Create a new DynamicTable for +collection+ with HTML attributes
    # +attributes+ and default request targets +targets+ using the template
    # +template+ for rendering.
    #
    # Internal method; see +dynamic_table+ for information on how to
    # create a dynamic table.
    def initialize(collection, template, attributes = {}, targets = {})
      @rows       = collection.map { |o| Row.new(o, {}) }
      @columns    = []
      @collection = collection
      @template   = template
      @components = {}

      @attributes = attributes || {}
      @targets    = targets    || {}
    end

    # Add a new column uniquely named +name+, with a header labelled +label+,
    # to the table. Accepts a block taking a single argument, an object from
    # the collection, to format a cell's contents with. For example,
    #   table.column("Name", :name) { |u| u.user_name }
    # would add a column titled "Name" with cells containing the result of
    # calling user_name on each object of the collection.
    #
    # If no block is supplied, the method will try to use +name+ as a
    # key to fetch the corresponding field: for example,
    #   table.column("Name", :name)
    # would correspond to
    #   table.column("Name", :name) { |u| u.name }
    # if u has a name method, or
    #   table.column("Name", :name) { |u| u[:name] }
    # if u is a hash with a :name key.
    # As a last resort, if u is an enumerable-like object, the column index
    # will be used.
    #
    # If +name+ is not supplied, it'll be inferred from +label+.
    #
    # Available options:
    # [pretty_name]
    #  Formatted column name to use when displaying simple textual labels for
    #  the column. Defaults to +label+. Use this option if +label+ contains
    #  HTML markup.
    #
    # [field_name]
    #  Name of the field to fetch inside the collection object (when no block
    #  is supplied) instead of +name+. Use this option if you want to keep the
    #  column name as +name+ (for cell css classes and other purposes) but
    #  want to try to fetch the field with a different key.
    #
    # [hidden]
    #  Whether or not this column is initially hidden in the table. The
    #  table's UI shows a small button at the end of column headers to
    #  hide/show columns.
    #
    # [sortable]
    #  Whether or not this column can be used to sort the table's rows with.
    #  If specified, the table's UI will show small arrows next to the column
    #  header indicating that it can be sorted.
    #  Note that specifying sort_order or sort_target will automatically mark
    #  the column as sortable.
    #
    # [sort_order]
    #  Current sort order of the column; one of :asc, :desc, :none or :auto.
    #  :asc and :desc correspond to, respectively, ascending order and
    #  descending order while :none indicates that while the column is
    #  sortable, the table is not currently sorted according to this column.
    #  Specifying :auto will take the sorting order from the Rails request
    #  parameters (params[<column name>][:sort_order]).
    #  Marks the column as sortable if specified, defaults to :auto if the
    #  column is already sortable.
    #
    # [sort_target]
    #  Function (lambda), hash or URL describing the target request to perform
    #  when sorting. See the analogous option sort_target for the
    #  +dynamic_table+ method for further information.
    #  Marks the column as sortable if specified.
    #
    # [filterable]
    #  Whether or not this column can be used to filter the table's rows with.
    #  If specified, the table's UI will show a small icon and popup next to
    #  the column header to allow filtering.
    #  Note that specifying filters or filter_target will automatically mark
    #  the column as filterable.
    #
    # [filters]
    #  Possible filters that can be applied for this column. Expected to be
    #  an Enumerable of hashes, each with at least the :value key. The hash
    #  keys used by this method are:
    #  [value]     Value to send back in the request should this filter be
    #              selected.
    #  [label]     Label for the filter in the filter list's UI. Defaults to
    #              the value if not present.
    #  [indicator] Special indicator value to be shown next to the label in the
    #              UI. Usually used for the number of table rows matching the
    #              filter. Note that specifying '0' will disable selection of
    #              the filter. Defaults to '-'.
    #  If you supply an Enumerable of arrays or strings instead, they will be
    #  converted to hashes in the following manner:
    #    [1, "A"]    => { :value =>   1, :label => "A", :indicator => '-' }
    #    [1, "A", 2] => { :value =>   1, :label => "A", :indicator => 2   }
    #    "A"         => { :value => "A", :label => "A", :indicator => '-' }
    #  Marks the column as filterable if specified.
    #
    # [filter_target]
    #  Same as sort_target, but for filtering instead of sorting.
    #  Marks the column as filterable if specified.
    #
    # [header_html]
    #  Hash of HTML attributes to add to the column header cell tag.
    #  For example,
    #    t.column("A", :a, :header_html => { :id => 'foo' })
    #  will make the column header tag have id 'foo':
    #    <th id="foo">
    #      ...
    #    </th>
    #
    # [cell_html]
    #  Hash of HTML attributes to add to each cell tag in the column.
    #  Behaves similarly to header_html.
    #
    # [html]
    #  Alias for header_html
    #
    # [id]
    #  Set the HTML id attribute of the column header.
    #  Shorthand for :html => { :id => <value> }
    #
    # [class]
    #  Add the given CSS classes to the column header.
    #  Shorthand for :html => { :class => <value> }
    def column(label, name = nil, options = {}, &block)
      # Header HTML attributes
      header_attr         = options[:header_html] || options[:html] || {}
      header_attr[:id]    = options[:id]    if options[:id]
      header_attr[:class] = options[:class] if options[:class]
      header_attr[:class] = DynamicTable.parse_css_classes(header_attr[:class])

      # Cell HTML attributes
      cell_attr           = options[:cell_html] || {}
      cell_attr[:class]   = DynamicTable.parse_css_classes(cell_attr[:class])

      # Regular attributes
      name          = (name || label.to_s.underscore).to_sym
      pretty_name   = (options[:pretty_name] || label).to_s
      field_name    = (options[:field_name]  || name).to_sym
      hidden        = options[:hidden]

      # Wrap an arbitrary target into a lambda function
      as_func = lambda do |target|
        return target if target.respond_to?(:call)
        lambda { |a, b| target.is_a?(String) ? target : url_for(target) }
      end

      # Sorting
      sort_target = as_func.call(options[:sort_target] || @targets[:sort])
      sort_order  = options[:sort_order]  || :auto

      # Filtering
      filter_target = as_func.call(options[:filter_target] || @targets[:filter])
      filters       = options[:filters].map do |f|
        if f.is_a?(Enumerable)
          val, lbl, ind = f.to_a
          { :value => val,    :label => lbl || val, :indicator => ind || '-' }
        elsif f.is_a?(String) || f.is_a?(Symbol)
          { :value => f.to_s, :label => f.to_s,     :indicator => '-'        }
        else
          f
        end
      end if options[:filters]

      # Default formatting procedure
      index  = @columns.length
      format = block || Proc.new do |obj|
        if obj.respond_to?(field_name)
          obj.send(field_name)
        elsif obj.respond_to?(:[]) && (obj[field_name] rescue nil)
          obj[field_name]
        elsif obj.is_a?(Enumerable)
          obj.to_a[index]
        else
          raise "Cannot fetch field #{field_name} from #{obj}"
        end
      end

      # Condense related attribute into hashes
      header = { :label  => label,  :attributes => header_attr }
      cell   = { :format => format, :attributes => cell_attr   }

      sort   = { :target => sort_target, :order => sort_order }  if
        [:sortable, :sort_target, :sort_order].any? { |k| options[k] }

      filter = { :target => filter_target, :filters => filters } if
        [:filterable, :filter_target, :filters].any? { |k| options[k] }

      # Add the column
      @columns << Column.new(name, header, cell,
        :pretty_name => pretty_name,
        :hidden      => hidden,
        :sort        => sort,
        :filter      => filter
      )
    end

    # Change the attributes of all table rows. Accepts a block taking a single
    # argument, an object from the collection, to compute the attributes of a
    # single row. The block should return a hash with keys corresponding to
    # those available as options to this method. The options returned from the
    # block will only apply to the corresponding row, while those specified as
    # method arguments will apply to all rows in the table.
    #
    # Available options:
    # [html]
    #  Hash of HTML attributes to add to the row tag. See +column+'s html option
    #  for an example.
    #
    # [id]
    #  Set the HTML id attribute of row.
    #  Shorthand for :html => { :id => <value> }
    #
    # [class]
    #  Add the given CSS classes to row.
    #  Shorthand for :html => { :class => <value> }
    #
    # [selectable]
    #  Whether or not this row can be selected. If specified, the table will
    #  have an extra column with checkboxes to allow selection.
    #  Note that specifying selected, select_value or select_param will
    #  automatically mark the row as selectable.
    #
    # [selected]
    #  Whether or not this row is initially selected. Selected rows have checked
    #  checkboxes in the checkbox column.
    #  Marks the row as selectable if specified.
    #
    # [select_value]
    #  Value to send back in the request should this row be selected.
    #  Can be a lambda, which will be invoked on the collection object to
    #  fetch the value. Defaults to trying the fetch the object's id
    #  (method or hash key), falling back to the hash method if the object
    #  doesn't have an id key or method.
    #  Marks the row as selectable if specified.
    #
    # [select_param]
    #  Parameter name in the request to send select_value as. To send back all
    #  selected values as an array, use the same select_param for all rows.
    #  Defaults to 'selection'.
    #  Marks the row as selectable if specified.
    #
    # [override]
    #  Lambda function to call for generating table rows instead of the table's
    #  automatic row generation mechanism. The lambda will be passed 3
    #  arguments; the collection object to create the row for, a
    #  DynamicTable::Row object containing row attributes and the DynamicTable
    #  object itself.
    #  Note that the table column visibility feature (see the hidden column
    #  option) requires table cells to have a css class matching the column
    #  name.
    def row(options = {}, &block)
      # Apply to existing rows
      @rows.each { |row| row.apply(options.clone, &block) }

      # Store for future rows (created by a render :row, for example)
      (@row_options ||= {}).deep_merge!(options)
      @row_block = block
    end

    # Mark rows as selectable. Equivalent to the selectable, selected,
    # select_value and select_param row options, with +value+ corresponding to
    # select_value and +param+ to select_param. See the corresponding +row+
    # method options for further information.
    def selectable(param = nil, value = nil, selected = nil)
      self.row(
        :selectable   => true,
        :selected     => selected,
        :select_param => param,
        :select_value => value
      )
    end

    # Add pagination elements to the table, such as previous/next buttons,
    # a page list and an item-per-page input. +location+, if given, is expected
    # to be either :top, :bottom or :both and corresponds to where the pagination
    # elements will be located relative to the table. If +location+ is not
    # specified, the pagination will be located at the top if no columns have
    # been defined on the table yet, and at the bottom otherwise.
    #
    # Available options:
    # [collection]
    #  Collection to paginate instead of the table's own collection. Useful if,
    #  for example, the orignal collection to display is already paginated but
    #  needs to be transformed before rendering;
    #    dynamic_table(@paginated_list.map { |e| .... } ) do |t|
    #      t.pagination(:top, :collection => @paginated_list)
    #      ...
    #    end
    #  Note that incorrect pagination may be generated if the collection given
    #  to paginate with (this option) is of the same length as the one used for
    #  rendering.
    #
    # [page]
    #  Current page number. Unless the collection is already paginated,
    #  defaults to taking value from Rails request parameters (params[:page]),
    #  falling back to the first (1) page if the parameter is not specified.
    #
    # [per_page]
    #  How many rows per page should the table have. Unless the collection
    #  is already paginated, defaults to taking the value from Rails request
    #  parameters (params[:per_page]), falling back to 25 rows per page if
    #  the parameter is not specified.
    #
    # [total_entries]
    #  Total entry count for the collection represented by the table. Defaults
    #  to the collection's length. The total entry count is usually
    #  different from the collection's length when the collection is already
    #  paginated.
    #
    # [input_html]
    #  Hash of HTML attributes to add to the per-page input tag. For example,
    #    t.pagination(:input_html => { :id => 'foo' })
    #  will make the input tag have id 'foo':
    #    <input id="foo" ... />
    #
    # [<...>]
    #  All other options to this method are passed directly to
    #  the will_paginate method of the will_paginate gem. See
    #  will_paginate's documentation for further information.
    #
    # Note that the page, per_page and total_entries options are ignored if the
    # table's collection is already paginated (already a WillPaginate::Collection)
    def pagination(location = nil, options = {})
      # If options are given without a location...
      if options.blank? && ! [:top, :bottom, :both].include?(location)
        options  = location || {}
        location = nil
      end

      collection = options.delete(:collection) || @collection
      @template.instance_eval do
        options[:page]          ||= params[:page]     || 1
        options[:per_page]      ||= params[:per_page] || 25
        options[:total_entries] ||= collection.length
      end

      @components[:pagination] = Pagination.new(
        location || (@columns.blank? ? :top : :bottom),
        collection,
        options  || {}
      )
    end

    alias_method :select,        :selectable
    alias_method :select_column, :selectable
    alias_method :paginated,     :pagination
    alias_method :paginate,      :pagination

    # Simple structure representing a single column in a dynamic table, including
    # headers, sorting, filtering and cell formatting.
    #
    # Internal class; use the +column+ method of DynamicTable to create and
    # manage columns.
    class Column
      # Unique name for this column. Identifies the column in requests and cell
      # CSS classes.
      attr_accessor :name
      # Nicer-looking plain-text name for the column
      attr_accessor :pretty_name
      # Column header to display. Instance of DynamicTable::Column::Header.
      attr_accessor :header
      # Template cell to generate the column cells with. Instance of
      # DynamicTable::Column::Cell
      attr_accessor :cell
      # Current sorting order of the column (:asc, :desc, :none or :auto)
      attr_accessor :sort_order
      # Target for sorting requests
      attr_accessor :sort_target
      # Available table filters on the column. Instances of
      # DynamicTable::Column::Filter
      attr_accessor :filters

      # Create a new Column named +name+, with header options +header+,
      # and cell options +cell+
      #
      # Available options:
      # [pretty_name]
      #  Formatted name to use for textual labels. Same as the pretty_name
      #  option of DynamicTable's +column+ method.
      #
      # [hidden]
      #  Whether or not this column is hidden by default. See the hidden option
      #  for DynamicTable's +column+ method for more information.
      #
      # [sort]
      #  Hash of parameters used for sorting. The possible keys are:
      #  [target]  Function (lambda) describing the target request
      #            to perform when sorting.
      #  [order]   Current sort order of the column. Same as the sort_order
      #            option of DynamicTable's +column+ method.
      #  If not present, the column wont offer sorting capabilities
      #
      # [filter]
      #  Hash of parameters used for filtering. The possible keys are:
      #  [target]  Function (lambda) or URL describing the target request
      #            to perform when filtering.
      #  [filters] Enumerable of hashes describing the filters available for
      #            this column. See the filters option to DynamicTable's
      #            +column+ method for more information.
      #  If not present, the column wont offer filtering capabilities.
      def initialize(name, header, cell, options = {})
        @name        = name
        @pretty_name = options[:pretty_name] || name.to_s.titleize
        @hidden      = options[:hidden]
        @header      = Header.new(header[:label], header[:attributes])
        @cell        = Cell.new(cell[:format], cell[:attributes])

        if sort = options[:sort]
          @sort_order  = sort[:order]
          @sort_target = sort[:target]
        end

        if filter = options[:filter]
          @filters = filter[:filters].map do |f|
            Filter.new(f[:value], f[:label], filter[:target], f[:indicator])
          end
        end
      end

      # Simple structure representing a column header.
      Header = Struct.new(
        # HTML (or plain-text) label to show in the column's header cell
        :label,
        # HTML attributes to add to the header cell
        :attributes
      )

      # Simple structure representing a template cell for this column.
      Cell = Struct.new(
        # Formatting function to apply to collection objects to get column
        # cell contents
        :format,
        # HTML attributes to add to each of the column's cells
        :attributes
      )

      # Simple structure representing a table filter on this column.
      Filter = Struct.new(
        # Value to send back in the request for this filter to be applied
        :value,
        # Plain-text label to show for this filter in the filter list
        :label,
        # Target request to perform when this filter is selected
        :target,
        # Indicator value to show for this filter in the filter list next
        # to the label. '0' will disable selection of the filter.
        :indicator
      )

      # Whether or not the column is initially visible. The column's visibility
      # can be changed after render by the user using the hide/show columns
      # menu.
      def visible?
        !@hidden
      end

      # Whether or not this column can be sorted. A sortable column will have
      # small arrows next to the column header for sorting.
      def sortable?
        !!@sort_target
      end

      # Whether or not this column can be used to apply filters to the table.
      # A column with filters will have a small icon next to the column header
      # to allow filtering.
      def filterable?
        @filters && ! @filters.empty?
      end
    end

    # Simple structure representing a single row in the table holding one
    # of the collection's object.
    #
    # Internal structure; specify row attributes using DynamicTable's
    # +row+ method.
    Row = Struct.new(
      # Collection object represented by this row.
      :object,
      # HTML attributes to apply to the row.
      :attributes,
      # Lambda to call to render the row, overriding the automatic generation
      # mechanism.
      :override,
      # Value to send back in the request should this row be selected.
      :select_value,
      # Parameter name in the request to send select_value as.
      :select_param,
      # Assuming this row is selectable, whether it is initially selected or not.
      :selected
    ) do
      # Apply a set of +options+, possibly returned by calling +block+
      # on the row's collection object, to the row. Available options are
      # the same as those specified in DynamicTable's row method.
      def apply(options = {}, &block)
        options.merge!(block.call(self.object) || {}) if block

        # HTML options
        self.override = options[:override] if options.has_key?(:override)
        (self.attributes ||= {}).merge!(options[:html]) if options[:html]
        self.attributes[:id]    = options[:id]    if options[:id]
        self.attributes[:class] = options[:class] if options[:class]
        self.attributes[:class] = DynamicTable.parse_css_classes(self.attributes[:class])

        # Selection-related options
        unless [:selectable, :selected, :select_value, :select_param].all? { |k| options[k].nil? }
          obj = self.object

          self.selected       = options[:selected]
          self.select_value   = options[:select_value]
          self.select_value ||= obj.id   if obj.respond_to?(:id)
          self.select_value ||= obj[:id] if obj.respond_to?(:[]) && (obj[:id] rescue nil)
          self.select_value ||= obj.hash
          self.select_param   = options[:select_param] || 'selection'
        end
      end

      # Whether a row can be selected or not. Selectable rows have a checkbox
      # as the very first column to allow selection.
      def selectable?
        ! self.selected.nil? || self.select_value || self.select_param
      end
    end

    # Simple structure holding pagination attributes for the table.
    #
    # Internal structure; use DynamicTable's +pagination+ method to specify
    # pagination parmeters.
    class Pagination
      # Where (:top, :bottom) should the pagination element be rendered
      attr_accessor :location
      # Hash of HTML attributes for the rows-per-page input textbox
      attr_accessor :input_html
      # will_paginate-wrapped collection to display the pagination of
      attr_accessor :collection
      # will_paginate options
      attr_accessor :options

      # Create a new pagination component located at +location+ for
      # +collection+. The available options are exactly the same
      # as DynamicTable's +pagination+ method's options.
      def initialize(location, collection, options = {})
        page          = options.delete(:page)
        per_page      = options.delete(:per_page)
        total_entries = options.delete(:total_entries)
        @input_html   = options.delete(:input_html) || {}

        # Make sure we have a paginated collection.
        unless collection.is_a?(WillPaginate::Collection) || (
          # Paginated ActiveRecord relations will hopefully have a current_page
          # attribute set.
          collection.is_a?(ActiveRecord::Relation) &&
          collection.respond_to?(:current_page) &&
          collection.current_page
        )
          collection = collection.to_a.paginate(
            :page          => page,
            :per_page      => per_page,
            :total_entries => total_entries
          )
        end

        @collection = collection
        @location   = location
        @options    = options
      end
    end

    # Create a dynamic table for +collection+ with +options+ using +template+.
    # Expects a block taking a single argument, an instance of this class,
    # to add the table's columns and alter the table's properties.
    # This method is the class-side implementation (minus render) of
    # +dynamic_table+'s interface and thus has almost the same parameters;
    # +collection+ and +options+ are identical to +dynamic_table+'s.
    # They only differ in the +template+ parameter, which corresponds to
    # the templating engine's template (usually +self+ in +dynamic_table+).
    #
    # Note that calling any of the public API methods (+column+, +row+,
    # +pagination+, etc.) outside of the expected block may produce unexpected
    # behavior, as the table expects it's creation parameters to be static after
    # creation.
    #
    # Special API method; only use this method if you need to issue specific
    # calls to the render method (such as rendering only rows or pagination).
    # Otherwise, use +dynamic_table+ (which invokes this) to create and render
    # dynamic tables.
    def self.create(collection, template, options = {})
      attributes         = options[:html] || {}
      attributes[:id]    = options[:id]    if options[:id]
      attributes[:class] = options[:class] if options[:class]
      attributes[:class] = self.parse_css_classes(attributes[:class])

      attributes[:'data-selection-mode'] = options[:selection_mode] || :multiple
      attributes[:'data-request-type']   = options[:request_type]   || :html_link

      request_url     = template.instance_eval { request.path }
      sort_target     = options[:sort_target]
      sort_target   ||= request_url
      filter_target   = options[:filter_target]
      filter_target ||= request_url
      targets         = { :sort => sort_target, :filter => filter_target }

      table = self.new(collection, template, attributes, targets)
      table.instance_variable_set(:@row_selection, options[:row_selection]) if
        options[:row_selection]

      yield table

      table.apply_default_attributes
      table
    end

    # Render the specified dynamic table +element+ to HTML using the
    # shared/dynamic_table partial. +element+ can be one of:
    #
    # [full]
    #  Entire table, extra UI components included.
    #
    # [table]
    #  Just the core table, without extra UI components.
    #
    # [header]
    #  Bare column headers (with sorting/filtering UI)
    #
    # [row]
    #  A set of rows. +args+ will be expected to contain either an Enumerable
    #  (or a single) +Row+ instance or a collection item to generate
    #  the row from.
    #
    # [<component>]
    #  Just the UI component (<component>) requested. Make sure the requested
    #  UI component is present on the table, as the render will obviously
    #  fail otherwise.
    #
    # Note that only specifying +full+ will render a fully functional table, as
    # it will render the container element to which client-side events are
    # bound.
    #
    # Special API method; the +dynamic_table+ module method will automatically
    # render the entire table once created. Only use this method in conjunction
    # with the +create+ class method if you need to render specific elements
    # separately.
    def render(element = :full, *args)
      rows = (args[0].is_a?(Enumerable) ? args[0] : [args[0]]).map do |obj|
        row = obj.is_a?(Row) ? obj : Row.new(obj, {})
        row.apply(@row_options.clone, &@row_block)
        row
      end if element == :row

      table = self
      @template.instance_eval do
        render(:partial => "shared/dynamic_table", :locals => {
          :table   => table,
          :element => element,
          :args    => [rows]
        })
      end
    end

    # Apply default column header and cell HTML attributes prior to rendering.
    #
    # Note that this method should only be called once; it does not check if the
    # attributes are already there.
    #
    # Internal method; the default attributes are automatically added at table
    # creation (+create+).
    def apply_default_attributes
      # Add header specific attributes
      @columns.each do |column|
        header = column.header
        cls    = (header.attributes[:class] ||= [])
        cls   << column.name.to_s
        cls   << 'dt-hidden' if ! column.visible?
        cls   << 'dt-sort'   if column.sortable?
        cls   << 'dt-filter' if column.filterable?
        header.attributes['data-column'] ||= column.name.to_s
      end

      # Add cell specific attributes
      @columns.each do |column|
        cell  = column.cell
        cls   = (cell.attributes[:class] ||= [])
        cls  << column.name.to_s
        cls  << 'dt-hidden' if ! column.visible?
        cell.attributes['data-column'] ||= column.name.to_s
      end
    end

    # Whether or not this table allows the user to select rows using a
    # checkbox column.
    #
    # Internal method; used when rendering to know whether or not to add a
    # checkbox column. Use the +selectable+ and +row+ methods to make rows
    # selectable or use +dynamic_table+'s row_selection option to force
    # the table to have a checkbox column.
    def has_row_selection?
      @row_selection || @rows.any? { |row| row.selectable? }
    end

    # Parse a string, symbol or array (+classes+) into proper css class names.
    # For example, [:red, "blue green", nil] -> ["red", "blue", "green"]
    def self.parse_css_classes(classes)
      classes = [classes] unless classes.is_a?(Enumerable)
      classes
        .to_a
        .flatten
        .delete_if(&:blank?)
        .map { |v| v.to_s.split(' ') }
        .flatten
    rescue
      []
    end

    # Generate a unique ID string for table HTML elements.
    def self.generate_id
      @@last_id ||= 0
      "_dyntbl_#{@@last_id += 1}"
    end

    def generate_id #:nodoc:
      self.class.generate_id
    end

  end

  # Create a dynamic table for +collection+, an Enumerable-like object.
  # Expects a block taking a single argument, a DynamicTable object, which
  # will be used to add columns and modify the table's properties.
  #
  # Available options:
  # [html]
  #  Hash of HTML attributes to add to the table tag.
  #  For example,
  #    dynamic_table(@list, :html => { id: => 'foo' }) do |t|
  #      ...
  #    end
  #  will make the top-level dynamic table table tag have id 'foo':
  #    <div class="dynamic_table" id="foo">
  #      ...
  #    </div>
  #
  # [id]
  #  Set the HTML id attribute of the table.
  #  Shorthand for :html => { :id => <value> }
  #
  # [class]
  #  Add the given CSS classes to the table.
  #  Shorthand for :html => { :class => <value> }
  #
  # [sort_target]
  #  Function (lambda), hash or URL describing the target request to
  #  perform when sorting. The lambda function will be given 2 arguments;
  #  the column name to sort and the current sorting order (:none,
  #  :asc or :desc). It is expected to return a hash (on which url_for
  #  will be called) or an URL directly. If you wish to have the same
  #  target for all sorting requests, pass a hash or URL (string) directly
  #  to this method. It is equivalent to a function just returning that
  #  hash (or URL). To specify per-column targets, use the +column+ method's
  #  sort_target option. Defaults to the current URL.
  #
  # [filter_target]
  #  Same as sort_target, but for filtering instead. The 2 arguments passed
  #  to the lambda function will be the column name and the filter object.
  #
  # [render]
  #  Whether the table should be automatically rendered after creation or not.
  #  Specifying false (as it defaults to true) will make dynamic_table
  #  return the table instead of calling render. This mimics calling
  #  DynamicTable.create and allows only rendering parts of the table.
  #
  # [row_selection]
  #  Whether or not table rows are expected to be selectable. If this option is
  #  set, the table will have a separate column with checkboxes to allow
  #  selecting rows and the header's checkbox will select all rows in the table.
  #  Note that this option is automatically set if any row in the table is
  #  marked as selectable (see the +selectable+ and +row+ DynamicTable methods).
  #
  # [selection_mode]
  #  Specifies how many rows can be selected at once in the table. Either
  #  :single, to only allow a single row to be selected at a time, or :multiple
  #  (default) to allow an arbitrary number of rows to be selected.
  #  Only relevant if rows can be selected.
  #
  # [request_type]
  #  Type of request to perform when sorting and filtering. Available types:
  #
  #  [:ajax_replace]
  #   Perform the request using AJAX and replace the table with the contents
  #   of the response when a sorting or filtering link is triggered.
  #
  #  [:html_link]
  #   Follow regular HTML link behavior; when a sorting or filtering link is
  #   triggered, load the new page as if the user clicked a regular link.
  #
  #  [:server_javascript]
  #   Perform a GET request for a server-rendered javascript snippet to update
  #   the table when a sorting or filtering link is triggered.
  #
  #  Defaults to :html_link
  def dynamic_table(collection, options = {}, &block)
    table = DynamicTable.create(collection, self, options, &block)

    (options.has_key?(:render) && ! options[:render]) ? table : table.render
  end

  # This method is a simple variation of +dynamic_table+ (and DynamicTable)
  # to make creating index tables easier. For example, this method supplies
  # sort_target and filter_target lambda functions mimicking what
  # index_table (IndexTableHelper) would send.
  # This method's parameters are the same as +dynamic_table+'s, with the
  # following additional options:
  #
  # [sort_map]
  #  Mapping (hash) between table column names and the full column definitions
  #  used for sorting. For example, a column for user logins would have
  #  name :login and sorting definition 'users.login'. If a map for a given
  #  column name is not found, it defaults to the column name itself.
  #
  # [filter_map]
  #  Mapping (hash) between table column names and object fields used for
  #  filtering. For example, a column for user logins would have
  #  name :login and filtering field 'user_id'. If a map for a given
  #  column name is not found, it defaults to the column name itself.
  #
  # This method gives index_table-like defaults for:
  # * sort_target and filter_target
  # * fetching the sorting order and column (@filter_params)
  # * converting filters to DynamicTable's format ([<value>, <label>, <indicator>])
  # * sending how many rows per page should be displayed (per_page)
  def dynamic_index_table(collection, options = {}, &block)
    sort_map   = options[:sort_map]   || {}
    filter_map = options[:filter_map] || {}

    # Sorting parameters syntax:
    #  <controller>[sort_hash][order]=<column>&
    #  <controller>[sort_hash][dir]=<'ASC'|'DESC'>
    options[:sort_target] ||= lambda do |column,order|
      {
        :controller => params[:controller],
        :action     => params[:action],
        params[:controller] => { :sort_hash => {
          :order => sort_map[column] || column,
          :dir   => (order == :asc ? :desc : :asc).to_s.upcase
        } }
      }
    end

    # Use the filter_proxy mechanism to add filters
    options[:filter_target] ||= lambda do |column,filter|
      filter_column = filter_map[column] || column
      link = filter_add_link('', { :filters => { filter_column => filter.value } })
      link.match(/href="(.+?)"/)[1] # FIXME there is no filter_add_url...
    end

    table = (@@index_table_class ||= Class.new(DynamicTable) do
      attr_accessor :sort_map
      attr_accessor :filter_map

      define_method(:column) do |label, name = nil, options = {}, &block| #:nodoc:
        # If the column is sortable and its order set as :auto, use
        # filter_params' order value rather than the
        # params[<column>][:sort_order] default.
        filter_params = @template.instance_eval { @filter_params }
        sortable      = [:sortable, :sort_target, :sort_order].any? { |k| options[k] }
        is_auto       = ! options[:sort_order] || options[:sort_order] == :auto
        if sortable && is_auto
          name    = (name || label.to_s.underscore).to_sym
          order   = :none unless filter_params['sort_hash']['order'] == @sort_map[name]
          order ||= filter_params['sort_hash']['dir'].downcase.to_sym rescue :asc
          options[:sort_order] = order
        end

        # If we have index_table-like filters, convert them to DynamicTable's format
        options[:filters].map! do |label,hash|
          [hash[:filters].first[1], label]
        end if
          options[:filters] && options[:filters].all? do |filter|
            filter[1][:filters].first[1] rescue nil
          end

        super(label, name, options, &block)
      end

      define_method(:pagination) do |location = nil, options = {}| #:nodoc:
        # If options are given without a location...
        if options.blank? && ! [:top, :bottom, :both].include?(location)
          options  = location || {}
          location = nil
        end

        # Pre-set some HTML attributes for the per-page input
        (options[:input_html] ||= {}).merge!({
          :name        => 'per_page',
          :class       => 'search_box',
          :'data-type' => 'script',
          :'data-url'  =>  @template.instance_eval do
            url_for(:controller => params[:controller], :update_filter => true)
          end
        }) { |key,old,new| old }

        super(location, options)
      end

      alias_method :paginated, :pagination
      alias_method :paginate,  :pagination

    end).create(collection, self, options) do |table|
      # Make the table aware of the sorting and filtering mappings
      table.sort_map   = sort_map
      table.filter_map = filter_map

      block.call(table)
    end

    (options.has_key?(:render) && ! options[:render]) ? table : table.render
  end

end
