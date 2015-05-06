
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

# Helper for generating standard CBRAIN show tables. The developer
# describes the attributes and headers for cells in the table and
# the helper then produces the necessary HTML to arrange them on a
# page.
#
# The primary method used is +show_table+ which will be passed the
# object being described and a block. The block will be passed a
# TableBuilder object to be used to describe the table.
#   <%=
#     show_table(@feedbacks, :id => "feedback_table", :class => "resource_list") do |t|
#       ...
#     end
#   %>
#
# Here, @feedbacks is the list of object defining rows in the table. The second argument
# is just a hash table defining HTML attributes on the table.
module ShowTableHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Class that actually builds the table.
  class TableBuilder
    attr_accessor :cells, :width

    def initialize(object, template, options = {}) #:nodoc:
      @object          = object
      @template        = template
      @width           = options[:width] || 2
      @edit_disabled   = false
      @edit_disabled   = !options[:edit_condition] if options.has_key?(:edit_condition)
      @cells           = []
      @edit_cell_count = 0
    end

    # Returns true if the content is editable
    def editable?
      !@edit_disabled && @edit_cell_count > 0
    end

    # Generates a cell
    def cell(header = "", options = {}, &block)
      build_cell(ERB::Util.html_escape(header), @template.capture(&block), options)
    end

    # Generates a row
    def row(options = {}, &block)
      pad_row_with_blank_cells(options)
      build_cell("", @template.capture(&block), options.dup.merge( { :no_header => true, :show_width => @width } ) )
    end

    # Generates the attribute of a cell
    def attribute_cell(field, options = {})
      header = options[:header] || field.to_s.humanize
      build_cell(ERB::Util.html_escape(header), ERB::Util.html_escape(@object.send(field)), options)
    end

    # Generates an editable cell
    def edit_cell(field, options = {}, &block)
      header    = options.delete(:header) || field.to_s.humanize
      object    = @object
      options[:disabled] ||= @edit_disabled
      @edit_cell_count += 1 unless options[:disabled]
      build_cell(ERB::Util.html_escape(header), @template.instance_eval{ inline_edit_field(object, field, options, &block) }, options)
    end

    # Generates an editable checkbox
    def boolean_edit_cell(field, cur_value, checked_value = "1", unchecked_value = "0", options = {}, &block)
      options[:content] ||= @template.disabled_checkbox(cur_value == checked_value)
      if block_given?
        edit_cell(field, options, &block)
      else
        edit_cell(field, options) { @template.hidden_field_tag(field, unchecked_value) + @template.check_box_tag(field, checked_value, cur_value == checked_value) }
      end
    end

    # Generates an empty cell
    def empty_cell(n = 1, options = {})
      n.times { build_cell("","",options) }
    end

    # Generates X empty cells
    def empty_cells(n, options = {})
      empty_cell(n, options)
    end

    # Generates a blank row
    def blank_row(options = {})
      pad_row_with_blank_cells(options)
      row(options) { "&nbsp;".html_safe }
    end

    # Generates a row with empty cells
    def pad_row_with_blank_cells(options = {})
      in_current_row = (@cells.inject(0) { |tot,c| tot += c[1]; tot } ) % @width  # c[1] is the show_width of each cell
      empty_cell(@width - in_current_row, options) if in_current_row > 0
    end

    private

    def build_cell(head = "", content = "", options = {}) #:nodoc:
      no_header      = options.delete(:no_header)
      header_options = options.delete(:th_options) || {}
      cell_options   = options.delete(:td_options) || {}
      show_width     = options.delete(:show_width) || 1
      cell_options[:colspan] = (show_width-1)*2+1+(no_header ? 1 : 0) if show_width > 1 || no_header
      header_atts    = header_options.to_html_attributes
      cell_atts      = cell_options.to_html_attributes
      shared_atts    = options.to_html_attributes
      html = []
      unless no_header
        header = head.to_s
        header += ":" unless header.blank?
        html << "<th #{header_atts} #{shared_atts}>#{ERB::Util.html_escape(header)}</th>"
      end
      html << "<td #{cell_atts} #{shared_atts}>#{ERB::Util.html_escape(content.to_s)}</td>"
      @cells << [ html.join("\n").html_safe, show_width ]
    end
  end # End of TableBuilder

  # Shows the content of an attribute of an object
  # and provides an arbitrary input field to edit it (captured)
  def inline_edit_field(object, attribute, options = {}, &block)
    default_text = h(options.delete(:content) || object.send(attribute))
    return default_text if options.delete(:disabled)
    if object.errors.include?(attribute)
      default_text = "<span class=\"show_table_error\">#{default_text}</span>"
    end
    html = []
    html << "<span class=\"inline_edit_field_default_text\">"
    html << default_text
    html << "</span>"
    html << "<span class=\"inline_edit_field_input\" style=\"display:none\">"
    html << capture(&block)
    html << "</span>"
    html.join("\n").html_safe
  end

  # Not used right now?
  def inline_edit_form(object, attribute, url, options = {}, &block) #:nodoc:
    default_text = h(options.delete(:content) || object.send(attribute))
    return default_text if options.delete(:disabled)
    method = options.delete(:method) || :put
    if object.errors.include?(attribute)
      default_text = "<span style=\"color:red\">#{default_text}</span>"
    end
    html = []
    html << "<span class=\"inline_edit_form_default_text\">"
    html << default_text
    html <<    "<a href=\"#\" class=\"inline_edit_form_link action_link\">(edit)</a>"
    html << "</span>"
    html << "<span class=\"inline_edit_form\" style=\"display:none\">"
    html << form_tag(url, :method => method, :style => "display:inline", &block)
    html << "</span>"
    html.join("\n").html_safe
  end

  def show_table(object, options = {})
    header = options.delete(:header) || "Info"
    url    = options.delete :url
    method = options.delete :method

    tb = TableBuilder.new(object, self, options)
    yield(tb)

    if tb.editable? && object.is_a?(ActiveRecord::Base)
      unless url
        url = {:controller  => params[:controller]}
        if object.new_record?
          url[:action] = :create
        else
          url[:action] = :update
          url[:id]     = object.id
        end
        url = url_for(url)
      end

      unless method
        method = object.new_record? ? "post" : "put"
      end
    end


    html = []
    html << "<div class=\"inline_edit_field_group\">"
    if tb.editable?
      html << form_tag(url, :method => method)
    end
    html << "<fieldset>"
    html << "<legend>#{header}"
    if tb.editable?
      html << "<span class=\"show_table_edit\">(#{link_to "Edit", "#", :class => "show_table_edit_link inline_edit_field_link"})<span>"
    end
    html << "</legend>"
    html << "<table class=\"show_table\">"
    col_count = 0
    tb.cells.each do |cell|
      if col_count == 0
        html << "<tr>"
      end
      html      << cell[0] # content
      col_count += cell[1] # show_width of cell (1, 2, 3 etc)
      if col_count >= tb.width
        html << "</tr>"
        col_count = 0
      end
    end

    html << "</table>"

    if tb.editable?
      html << "<div class=\"inline_edit_field_input\" style=\"display:none\">"
      html << "<BR>"
      if object.new_record?
        html << submit_button("Create")
      else
        html << submit_button("Update")
      end
      html << "</div>"
      html << "</fieldset>"
      html << "</form>"
    else
      html << "</fieldset>"
    end

    html << "</div>"
    html.join("\n").html_safe
  end
end
