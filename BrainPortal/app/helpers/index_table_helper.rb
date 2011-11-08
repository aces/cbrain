# Helper for building standard index tables with sorting and basic 
# filtering. Essentially the developer will define the tables columns, 
# and thes column definitions will be used to create rows, one each, 
# for a collection of objects provided.
#
# The primary method used to build tables is +index_table+ which is given 
# a collection objects and a block. This block will be passed a 
# TableBuilder object ot be used to describe the table:
#   <%= 
#     index_table(@feedbacks, :id => "feedback_table", :class => "resource_list") do |t|
#       ...
#     end
#   %>
# 
# Here, @feedbacks is the list of object defining rows in the table. The second argument
# is just a hash table defining HTML attributes on the table.
#
# Columns are defined by one of four methods:
# [column] Define a basic column (no sorting). 
# [sort_column] Define a basic sorting column.
# [describe_column] Describe a more complex, non-sorting column.
# [describe_sort_column] Describe a more complex sorting column.
#
# #column and #sort_column both take a block to define the 
# data of their table sells. These blocks will be passed an
# element from the collection passed to #index_table (e.g.
# #feedbacks above). 
#
# For example, to describe a column for the feedback summary attribute:
#
#   <%= 
#     index_table(@feedbacks, :id => "feedback_table", :class => "resource_list") do |t|
#       t.column("Summary") { |fb| fb.summary }
#     end
#   %>
#
# To make the column sortable:
#
#   <%= 
#     index_table(@feedbacks, :id => "feedback_table", :class => "resource_list") do |t|
#       t.sort_column("Summary", 'Feedback', 'summary') { |fb| fb.summary }
#     end
#   %>
#
# The first three arguments to #sort_column are the header text, the model being sorted on,
# and the model attribute being sorted on.
#
# #describe_column and describe_sort_column take the same arguments as their counterparts, but
# the block they are passed is used to describe a column in more detail. They passed a Column
# object whose #cell method can be used to describe on or more cells. The #cell method takes
# an optional hash as its first arguments, which defines HTML attributes on the cell. The
# block passed to #cell should describe the contents of the cell based on a given element
# in the collection. The main reasons to describe a column in detail are if the attributes
# of the cell need to be defined, if more than one cell must be defined under one header,
# or if the diplay of cells is conditional.
#
# For example, the 'Operations' column in feecbacks has many cells and their display depends
# on the current user's permissions. The condition is set by the :if option to the #cell
# method:
#
#   <%= 
#     index_table(@feedbacks, :id => "feedback_table", :class => "resource_list") do |t|
#       ...
#       t.describe_column("Operations") do |col|
#         col.cell(:if => Proc.new { |fb| current_user.has_role?(:admin) || current_user.id == fb.user_id }) { |fb|  link_to 'Edit', {:action => :edit, :id => #{fb.id}}, :class  => 'action_link' }
#         col.cell(:if => Proc.new { |fb| current_user.has_role?(:admin) || current_user.id == fb.user_id }) { |fb| delete_button 'Delete', {:action => :destroy, :id => #{fb.id}} ... }
#       end
#     end
#   %>
#
# Note that there are wrapper methods for some common operations, such as edit and
# delete links, so the previous code could be written as the following:
#
#   <%= 
#     index_table(@feedbacks, :id => "feedback_table", :class => "resource_list") do |t|
#       ...
#       t.describe_column("Operations") do |col|
#         col.edit_link(:if => Proc.new { |fb| current_user.has_role?(:admin) || current_user.id == fb.user_id })    
#         col.delete_link(:if => Proc.new { |fb| current_user.has_role?(:admin) || current_user.id == fb.user_id })
#       end
#     end
#   %>
#
# Note also that if the :if condition fails, empty table cells will still be displayed,
# so the table will remain balanced. 
#
# Finally, to add filter links to a column, simply set the :filters option on any one of the 
# four column methods. The list of filters will be an array of array pairs. Each pair will
# have the text to display as its first element, and a hash representing the filteration 
# to be done as its second. For example, a filter list for the Country column in the
# users table might look like the following:
#  [["Canada", :country => "Canada"]["USA", :country => "USA"]["Egypt", :country => "Egypt"]["Bolivia", :country => "Bolivia"]]
#
# Note that some helper methods, #basic_filters_for and #association_filters_for have been defined 
# (see lib/basic_filter_helpers.rb for details) to construct these types of lists for basic 
# attribute or association filtering.

module IndexTableHelper
  
  #Class that actually builds the table.
  class TableBuilder
    
    attr_reader :columns
    
    
    ##############################
    # Inner class Column
    ##############################
    
    #Class representing a single column in the table.
    #A column is essentialy one header with one or 
    #several cells per row (the header will automatically
    #be expanded to fit over all cells).
    class Column
      
      attr_reader :cells
      
      def initialize(table, template) #:nodoc:
        @table = table
        @template = template
        @cells = []
      end
      
      # Describe a basic header (this shouldn't usually be
      # done manually. See TableBuilder#column or 
      # TableBuilder#describe_column)
      def header(text, options = {})
        @header_text    = text 
        @header_options = options
      end
      
      # Describe a sorting header (this shouldn't usually be
      # done manually. See TableBuilder#sort_column or 
      # TableBuilder#describe_sort_column)
      def sort_header(text, klass, attribute, options = {})
        @header_text = @template.instance_eval { ajax_sort_link text, klass, attribute }
        @header_options = options
      end

      # Describe a cell
      def cell(options = {}, &block)
        condition = options.delete(:if)
        @cells << [block, options, condition]
      end
      
      # Shortcut for creating a cell with a link to the object's edit page.
      def edit_link(options = {})
        self.cell(options) { |object|  @template.instance_eval { link_to 'Edit', { :action => :edit, :id => object.id }, :class  => 'action_link' } }
      end
      
      # Shortcut for creating a cell with  a ajax delete link for the object.
      def delete_link(options = {})
        confirm_proc = options[:confirm] || Proc.new { |o| "Are you sure you want to delete '#{o.name}'?" }
        self.cell(options) do |object|
          num_cells = @table.num_cells
          @template.instance_eval { delete_button 'Delete', {:action => :destroy, :id => object.id}, :class  => "action_link",
                                                                                   :confirm  => confirm_proc.call(object),
                                                                                   :target  => "##{object.class.name.underscore}_#{object.id}",
                                                                                   :loading_message  => "<td colspan='#{num_cells}' style='color:red; text-align:center'>Deleting...</td>"
          }
        end
      end
            
      def header_html #:nodoc:
        @header_options[:colspan] ||= @cells.size
        filters = @header_options.delete :filters
        
        unless filters.blank?
          @header_options[:onMouseOver] = "jQuery('#filters_list_#{self.object_id}').show()"
          @header_options[:onMouseOut]  = "jQuery('#filters_list_#{self.object_id}').hide()"
        end
        
        atts = @header_options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "}
        html = "<th #{atts}>#{@header_text}"
        unless filters.blank?
          html += "<br>\n"
          html += "<ul class=\"filter_list\" id=\"filters_list_#{self.object_id}\" style=\"display:none;\">\n"
          filters.each do |f|
            html += "<li>\n"
            html += @template.instance_eval { filter_add_link f[0], :filters => f[1] }
            html += "</li>\n"
          end
          html += "</ul>\n"
        end
        html += "</th>\n"
        
        html
      end
      
      def cell_html(object) #:nodoc:        
        html = []
        @cells.each do |cell|
          cell      = [cell] unless cell.is_a? Array 
          proc      = cell[0]
          options   = cell[1] || {}
          condition = cell[2]
          content   = proc ? proc.call(object) : "" if condition.blank? || condition.call(object)
          
          atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "}
          html << "<td #{atts}>#{content}</td>\n"
        end
        html.join("")
      end      

    end #End class column
    
    ####################################
    #TableBuilder methods
    ####################################
    
    def initialize(template) #:nodoc:
      @template = template
      @columns = []
    end
    
    # Describe a simple non-sorting column
    def column(header_text = "", options = {}, &block)
      build_column do |col|
        col.header header_text, options
        col.cell   &block
      end
    end
    
    # Describe a simple sorting column
    def sort_column(header_text, klass, attribute, options = {}, &block)
      build_column do |col|
        col.sort_header header_text, klass, attribute, options
        col.cell        &block
      end
    end
    
    # Describe a more complex non-sorting column
    def describe_column(header_text = "", options = {})
      build_column do |col|
        col.header header_text, options
        yield(col)
      end
    end
    
    # Describe a more complex sorting column
    def describe_sort_column(header_text, klass, attribute, options = {})
      build_column do |col|
        col.sort_header header_text, klass, attribute, options
        yield(col)
      end
    end
    
    # Set text for a table header (across all columns).
    def header(text)
      @table_header = text
    end
    
    def header_html #:nodoc:
      return "" unless @table_header
      "<tr><th colspan=\"#{self.num_cells}\">#{@table_header}</th></tr>\n"
    end
    
    #
    def row_attributes(options = {}, &block)
      @header_attributes = block || Proc.new { |obj| options }
    end
    
    def row_attribute_html(object)
      return "class=\"#{@template.cycle('list-odd', 'list-even')} row_highlight\" id=\"#{object.class.name.underscore}_#{object.id}\"" unless @header_attributes
      
      options = @header_attributes.call(object)
      
      atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "}
      atts
    end
    
    def row_override(&block)
      @row_override = block
    end
    
    def row_override?(object)
      @row_override ? true : false
    end
    
    def row_override_html(object)
      return "" unless @row_override
      
      @row_override.call(object)
    end
    
    # Manually set text to be displayed in an empty row.
    def empty(text)
      @empty_text = text
    end
    
    #Produce 'empty' row for an empty table.
    def empty_table_html
      empty_text = @empty_text || "There are no entries in this table."
      "<tr><td colspan=\"#{self.num_cells}\">#{empty_text}</td></tr>\n"
    end
    
    # Number of cells per row.
    def num_cells
      @columns.inject(0) { |total, c| total + c.cells.size }
    end
    
    private
    
    def build_column
      col = Column.new(self, @template)
      yield(col)
      @columns << col
    end
    
  end #End class TableBuilder
  
  # Build an index table.
  def index_table(collection, options = {})
    table_builder = TableBuilder.new(self)
    atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "}
    
    yield(table_builder)
    
    html = []

    html << "<table #{atts}>\n<tr>\n"
    html << table_builder.header_html
    table_builder.columns.each do |col|
      html << col.header_html + "\n"
    end
    html << "</tr>\n"

    if collection.empty?
      html << table_builder.empty_table_html
    else
      collection.each do |object|
        if table_builder.row_override?(object)
          html << table_builder.row_override_html(object)
        else
          html << "<tr #{table_builder.row_attribute_html(object)}>\n"
          table_builder.columns.each do |col|
            html << col.cell_html(object)
          end
          html << "</tr>\n"
        end
      end
    end
    html << "</table>\n"
    
    html.join("").html_safe
  end
end
