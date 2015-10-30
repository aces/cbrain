
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

  # Helper class to represent the show table properties required for rendering.
  # This object is the one passed to +show_table+'s block, and it keeps
  # track of each cell (field) to be rendered.
  class TableBuilder
    # Cells to be rendered to form the table, as an array of pairs
    # (cell HTML markup, individual cell width).
    attr_accessor :cells

    # Table width, in cells. This property holds how many cells should be
    # displayed per row, as show tables are mainly cell-based, rather than
    # column/row-based.
    attr_accessor :width

    # Create a new TableBuilder for +object+ using +template+ for rendering.
    # Available +options+ are the same as for the +show_table+ helper method.
    # Internal method; use +show_table+ (which uses this class) to create and
    # render show tables.
    def initialize(object, template, options = {}) #:nodoc:
      @object          = object
      @template        = template
      @width           = options[:width] || 2
      @edit_disabled   = false
      @edit_disabled   = !options[:edit_condition] if options.has_key?(:edit_condition)
      @cells           = []
      @edit_cell_count = 0
    end

    # Whether or not this table has editable content. An editable table will
    # have a toggle button to switch to edition mode.
    def editable?
      !@edit_disabled && @edit_cell_count > 0
    end

    # Generate a single cell for the table, optionally along with a header cell
    # containing +header+. Expects a block taking no arguments to generate
    # the contents of the cell.
    # Note that cells are placed from left to right in rows of *width* (width
    # attribute) cells.
    #
    # The available +options+ are:
    # [:no_header]
    #  Do not generate a header cell with the main content one. +head+ is
    #  ignored.
    #
    # [:show_width]
    #  Width (in cells or columns) of this cell in the table. For example,
    #  if a table has 2 cells per row, a show_width of 2 would make the
    #  generated cell as wide as the entire table. Defaults to 1.
    #
    # [:th_options]
    #  HTML attributes to tackle on the generated header cell. Note that
    #  +build_cell+ does not have any default attributes for header cells.
    #
    # [:td_options]
    #  Same as :th_options, but for the content cell. Note that +build_cell+
    #  may override any colspan attribute given in +td_options+, if required.
    #
    # [<...>]
    #  All other options are added as HTML attributes to both the generated
    #  header and content cells.
    def cell(header = "", options = {}, &block)
      build_cell(ERB::Util.html_escape(header), @template.capture(&block), options)
    end

    # Generate a new table row containing a single cell as wide as the table.
    # Expects a block taking no arguments to generate the contents of the cell.
    # The available +options+ are the same as for +cell+ (and will apply to the
    # single cell filling the row) except for +no_header+ and +show_width+,
    # which are respectively set to true (as there is no header for full-row
    # cells) and the width of the table. Note that this method will also pad the
    # last row with blanks before adding the new row
    # (see +pad_row_with_blank_cells+).
    def row(options = {}, &block)
      pad_row_with_blank_cells(options)
      build_cell("", @template.capture(&block), options.dup.merge( { :no_header => true, :show_width => @width } ) )
    end

    # Generate a cell for a field named +field+ inside the table's source
    # object. This method has the same +options+ as the +cell+ method, with
    # one addition:
    # [:header]
    #  Contents for the header cell to generate along with the field cell.
    #  Defaults to +field+ (field name).
    def attribute_cell(field, options = {})
      header = options[:header] || field.to_s.humanize
      build_cell(ERB::Util.html_escape(header), ERB::Util.html_escape(@object.send(field)), options)
    end

    # Generate an editable cell for a field named +field+ inside the table's
    # source object. Expects a block taking no arguments to generate HTML
    # markup for editing +field+ (use +inline_edit_field+'s +content+ option
    # to specify the cell's contents in display mode).
    # Unless edition is disabled, the generated cell will toggle between display
    # and edition mode when the table's edition toggle button is used.
    #
    # This method supports both +cell+ and +inline_edit_field+'s
    # options, with one addition:
    # [:header]
    #  Contents for the header cell to generate along with the field cell.
    #  Defaults to +field+ (field name).
    def edit_cell(field, options = {}, &block)
      header    = options.delete(:header) || field.to_s.humanize
      object    = @object
      options[:disabled] ||= @edit_disabled
      @edit_cell_count += 1 unless options[:disabled]
      build_cell(ERB::Util.html_escape(header), @template.instance_eval{ inline_edit_field(object, field, options, &block) }, options)
    end

    # Generates an editable checkbox cell for +field+, of which the current
    # value is expected to be +cur_value+, a checked checkbox corresponding to
    # +checked_value+ and an unchecked one to +unchecked_value+.
    #
    # A specialization of +edit_cell+, this method provides some useful
    # defaults when generating checkbox cells:
    # - The cell's contents in display mode default to a disabled checkbox
    # - If no block is given, the edition mode markup defaults to an hidden
    #   field for +unchecked_value+ and a checkbox for +checked_value+.
    #
    # As +boolean_edit_cell+ is a specialization of +edit_cell+, +field+,
    # +&block+ and +options+ are handled the same way (save for the defaults
    # outlined above).
    def boolean_edit_cell(field, cur_value, checked_value = "1", unchecked_value = "0", options = {}, &block)
      options[:content] ||= @template.disabled_checkbox(cur_value == checked_value)
      if block_given?
        edit_cell(field, options, &block)
      else
        edit_cell(field, options) { @template.hidden_field_tag(field, unchecked_value) + @template.check_box_tag(field, checked_value, cur_value == checked_value) }
      end
    end

    # Generate +n+ empty cells (blank content and header), each with the same
    # +options+. Available +options+ are the same as the ones for +cell+.
    #
    # FIXME: +options+ is destructively modified in +build_cell+, meaning only
    # the first cell will have +options+ applied.
    def empty_cell(n = 1, options = {})
      n.times { build_cell("","",options) }
    end

    # Alias for +empty_cell+ (see +empty_cell+).
    def empty_cells(n, options = {})
      empty_cell(n, options)
    end

    # Generate a new blank/empty table row. A simple wrapper around +row+, this
    # method takes the same arguments save for the block, which isn't required
    # as there is no content to display. See +row+ for more information on how
    # rows are generated.
    def blank_row(options = {})
      pad_row_with_blank_cells(options)
      row(options) { "&nbsp;".html_safe }
    end

    # Fill the last table row with empty cells (+empty_cell+). Each generated
    # empty cell is generated with the same +options+, which are the same as
    # the ones for +cell+.
    def pad_row_with_blank_cells(options = {})
      in_current_row = (@cells.inject(0) { |tot,c| tot += c[1]; tot } ) % @width  # c[1] is the show_width of each cell
      empty_cell(@width - in_current_row, options) if in_current_row > 0
    end

    private

    # Generate a single show table cell containing +content+, usually along with
    # another header cell containing +head+. Internal method backing most
    # cell-generating methods in TableBuilder. Available +options+ are the
    # same as those specified for the +cell+ method.
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
  end # class TableBuilder

  # Generate an input field for +attribute+ within +object+ which can be
  # toggled by the user into either display or edition mode. This helper method
  # is designed to be used within a show table, as the table's layout will
  # provide the toggle button it requires. Expects a block taking no arguments
  # to generate the HTML markup to render when in edition mode. In display mode,
  # the field just shows +attribute+'s value.
  #
  # The available +options+ are:
  # [:content]
  #  Content to show in display mode instead of +attribute+'s value.
  #
  # [:disabled]
  #  Disable edition; this field will always stay in display mode and will
  #  ignore the show table's toggle button.
  #
  # Note that +object+ needs to look like an AR record, as it is expected to
  # have an errors method. If it has one and it contains +attribute+, the
  # display mode's text will reflect the erroneous state of the attribute.
  def inline_edit_field(object, attribute, options = {}, &block)
    default_text = h(options.delete(:content) || object.send(attribute))
    return default_text if options.delete(:disabled)
    if object.errors.include?(attribute)
      default_text = "<span class=\"show_table_error\">#{default_text}</span>"
    end

    html = <<-HTML.html_safe
      <span class="inline_edit_field_default_text">
      #{default_text}
      </span>
      <span class="inline_edit_field_input" style="display:none">
    HTML
    html += capture(&block) +
            "</span>".html_safe
    return html
  end

  # Create a show (and edition) table for +object+, which is expected to be
  # an AR record (or a similar object) to use for most table values.
  # Expects a block taking a single argument, a TableBuilder object, to specify
  # which fields of +object+ to display (see TableBuilder's methods for more
  # information).
  #
  # The available +options+ are:
  # [header]
  #  Title (header), to place on top of the table. Defaults to "Info".
  #
  # [url]
  #  URL (as a string) to perform the edition request on should +object+ be
  #  editable using this table. Defaults to an URL to the current controller
  #  for the +create+ action if +object+ does not exist yet in the DB, or
  #  +update+ with +object+'s ID otherwise.
  #
  # [method]
  #  HTTP method to perform the edition request with, should +object+ be
  #  editable using this table. Defaults to POST if the object has not been
  #  saved yet, PUT otherwise.
  #
  # [width]
  #  Table row width, in cells (in other words, the column count).
  #  Defaults to 2 cells per row.
  #
  # [edit_condition]
  #  Whether or not to make the table's fields editable by the user. If the
  #  table is editable (+edit_condition+ is specified as true), an edit toggle
  #  will be added next to the header/title to switch into edition mode.
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

