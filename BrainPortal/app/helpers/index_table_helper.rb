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
# on the current user's permissions:
#
# To make the column sortable:
#
#   <%= 
#     index_table(@feedbacks, :id => "feedback_table", :class => "resource_list") do |t|
#       ...
#       t.describe_column("Operations") do |col|
#         col.cell { |fb|  link_to 'Edit', {:action => :edit, :id => #{fb.id}}, :class  => 'action_link' }
#         col.cell { |fb| delete_button 'Delete', {:action => :destroy, :id => #{fb.id}} ... }
#         col.condition { |fb| current_user.has_role?(:admin) || current_user.id == fb.user_id}
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
#         col.edit_link    
#         col.delete_link(5)
#         col.condition { |fb| current_user.has_role?(:admin) || current_user.id == fb.user_id}
#       end
#     end
#   %>
#
# If different conditions need to be set on cells in the same column, this can be done by 
# passing the :condition option to #cell, as is done in the users 'Operations' column:
#
#   t.describe_column("Operations") do |col|
#     col.delete_link(11, :condition => Proc.new { |u| u != User.admin })
#     col.cell(:condition => Proc.new { |u| u != User.admin }) { |u| link_to 'Switch',  switch_user_path(u), :class => 'action_link', :method  => :post  }
#     col.cell { |u| link_to 'Access?', { :controller => :tool_configs, :action => :index, :user_id => u.id }, :class => 'action_link' }
#   end
#
# Finally, to add filter links to a column, simply set the :filters option on any one of the 
# four column methods. The list of filters will be an array of array pairs. Each pair will
# have the text to display as its first element, and a hash representing the filteration 
# to be done as its second. For example, a filter list for the Country column in the
# users table might look like the following:
#  [["Canada", :country => "Canada"]["USA", :country => "USA"]["Egypt", :country => "Egypt"]["Bolivia", :country => "Bolivia"]]
#
# Note that some helper methods, #basic_filters_for and #association_filters_for have been defined in ApplicationController
# to construct these types of lists for basic attribute or association filtering.

module IndexTableHelper
  
  #Class that actually builds the table.
  class TableBuilder
    
    attr_reader :columns
    
    #Class representing a single column in the table.
    #A column is essentialy one header with one or 
    #several cells per row (the header will automatically
    #be expanded to fit over all cells).
    class Column
      
      def initialize(view_binding) #:nodoc:
        @binding = view_binding
        @condition = Proc.new { |object|  true }
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
        @header_text = @binding.eval("ajax_sort_link '#{text}', '#{klass}', '#{attribute}'")
        @header_options = options
      end

      # Describe a cell
      def cell(options = {}, &block)
        @cells << [block, options]
      end
      
      # Define the condition for displaying all cells of this column.
      def condition(&cond)
        @condition = cond.to_proc
      end
      
      # Shortcut for creating a cell with a link to the object's edit page.
      def edit_link(options = {})
        @cells << [Proc.new { |object|  @binding.eval("link_to 'Edit', {:action => :edit, :id => #{object.id}}, :class  => 'action_link'") }, options]
      end
      
      # Shortcut for creating a cell with  a ajax delete link for the object.
      def delete_link(table_columns = 5, options = {})
        @cells << [Proc.new do |object| 
          @binding.eval("delete_button 'Delete', {:action => :destroy, :id => #{object.id}}, :class  => \"action_link\"," +
                                                                                   ":confirm  => 'Are you sure?'," + 
                                                                                   ":target  => \"##{object.class.name.underscore}_#{object.id}\"," +
                                                                                   ":target_text  => \"<td colspan='#{table_columns}' style='color:red; text-align:center'>Deleting...</td>\""
                
               )
        end, options]
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
            html += @binding.eval("filter_add_link \"#{f[0]}\", :filters => #{f[1]}\n")
            html += "</li>\n"
          end
          html += "</ul>\n"
        end
        html += "</th>\n"
        
        html
      end
      
      def cell_html(object) #:nodoc:
        return "<td colspan=\"#{@cells.size}\">" unless @condition.to_proc.call(object)
        
        html = ""
        @cells.each do |cell|
          cell = [cell] unless cell.is_a? Array 
          proc    = cell[0]
          options = cell[1] || {}
          condition = options.delete(:condition) || Proc.new { |o| true  }
          content = proc.call(object) if condition.call(object)
          
          atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "}
          html += "<td #{atts}>#{content}</td>"
        end
        html
      end      

    end #End class column
    
    #TableBuilder methods
    def initialize(view_binding) #:nodoc:
      @binding = view_binding
      @columns = []
    end
    
    # Describe a simple non-sorting column
    def column(header_text = "", options = {}, &block)
      col = Column.new(@binding)
      col.header header_text, options
      col.cell   &block
      @columns << col
    end
    
    # Describe a simple sorting column
    def sort_column(header_text, klass, attribute, options = {}, &block)
      col = Column.new(@binding)
      col.sort_header header_text, klass, attribute, options
      col.cell   &block
      @columns << col
    end
    
    # Describe a more complex non-sorting column
    def describe_column(header_text = "", options = {})
      col = Column.new(@binding)
      col.header header_text, options
      yield(col)
      @columns << col
    end
    
    # Describe a more complex sorting column
    def describe_sort_column(header_text, klass, attribute, options = {})
      col = Column.new(@binding)
      col.sort_header header_text, klass, attribute, options
      yield(col)
      @columns << col
    end
    
  end #End class TableBuilder
  
  # Build an index table.
  def index_table(collection, options = {}, &block)
    table_builder = TableBuilder.new(block.binding)
    atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "}
    
    block.call(table_builder)
    
    html = "<table #{atts}>\n<tr>\n"
    table_builder.columns.each do |col|
      html += col.header_html + "\n"
    end
    html += "</tr>\n"
    collection.each do |object|
      html += "<tr class=\"#{cycle('list-odd', 'list-even')} row_highlight\" id=\"#{object.class.name.underscore}_#{object.id}\">"
      table_builder.columns.each do |col|
        html += col.cell_html(object)
      end
      html += "</tr>\n"
    end
    html += "</table>\n"
    
    html.html_safe
  end
end