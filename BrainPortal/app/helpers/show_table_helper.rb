module ShowTableHelper
  class TableBuilder
    attr_accessor :cells, :width
    
    def initialize(object, template, options = {})
      @object         = object
      @template       = template
      @width          = options[:width] || 2
      @edit_path      = options[:edit_path]
      @edit_disabled  = false
      @edit_disabled  = !options[:edit_condition] if options.has_key?(:edit_condition)
      @cells          = []
    end
    
    def cell(header, options = {}, &block)
      build_cell(ERB::Util.html_escape(header), @template.capture(&block), options)
    end
    
    def row(options = {}, &block)
      build_cell("", @template.capture(&block), options.dup.merge( { :no_header => true, :show_width => @width } ) )
    end
    
    def attribute_cell(field, options = {})
      header = options[:header] || field.to_s.humanize
      build_cell(ERB::Util.html_escape(header), ERB::Util.html_escape(@object.send(field)), options)
    end
    
    def edit_cell(field, options = {}, &block)
      header    = options.delete(:header) || field.to_s.humanize
      edit_path = @edit_path || options.delete(:edit_path)
      object    = @object
      options[:disabled] ||= @edit_disabled
      build_cell(ERB::Util.html_escape(header), @template.instance_eval{ inline_edit_field(object, field, edit_path, options, &block) }, options)
    end

    def boolean_edit_cell(field, checked, checked_value = "1", unchecked_value = "0", options = {}, &block)
      options[:content] ||= @template.disabled_checkbox(checked)
      if block_given?
        edit_cell(field, options, &block)
      else
        edit_cell(field, options) { @template.hidden_field_tag(field, unchecked_value) + @template.check_box_tag(field, checked_value, checked.present?, :class => "submit_onchange") }
      end
    end
    
    def empty_cell(n = 1, options = {})
      n.times { build_cell("","",options) }
    end
    
    def empty_cells(n, options = {})
      empty_cell(n, options)
    end

    def blank_row(options = {})
      row(options) { "&nbsp;".html_safe }
    end
    
    private
    
    def build_cell(head = "", content = "", options = {})
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
  end
  
  def inline_edit_field(object, attribute, url, options = {}, &block)
     default_text = h(options.delete(:content) || object.send(attribute))
     return default_text if options.delete(:disabled)
     method = options.delete(:method) || :put
     if object.errors.include?(attribute)
       default_text = "<span style=\"color:red\">#{default_text}</span>"
     end
     html = []
     html << "<span class=\"inline_edit_field_default_text\">"
     html << default_text
     html <<    "<a href=\"#\" class=\"inline_edit_field_link action_link\">(edit)</a>"
     html << "</span>"
     html << "<span class=\"inline_edit_field_form\" style=\"display:none\">"
     html << form_tag(url, :method => method, :style => "display:inline", &block)
     html << "</span>"
     html.join("\n").html_safe
   end
  
  def show_table(object, options = {})
    header = options.delete(:header) || "Info"
    tb = TableBuilder.new(object, self, options)
    
    yield(tb)
    
    html = []
    
    html << "<fieldset>"
    html << "<legend>#{header}</legend>"
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
    html << "</fieldset>"
    
    html.join("\n").html_safe
  end
end
