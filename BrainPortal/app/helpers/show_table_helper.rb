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
    
    def cell(header, &block)
      build_cell(ERB::Util.html_escape(header), @template.capture(&block))
    end
    
    def row(&block)
      build_cell("", @template.capture(&block), :no_header => true, :colspan => @width * 2)
    end
    
    def attribute_cell(field, options = {})
      header = options[:header] || field.to_s.humanize
      build_cell(ERB::Util.html_escape(header), ERB::Util.html_escape(@object.send(field)))
    end
    
    def edit_cell(field, options = {}, &block)
      header    = options.delete(:header) || field.to_s.humanize
      edit_path = @edit_path || options.delete(:edit_path)
      object    = @object
      options[:disabled] ||= @edit_disabled
      build_cell(ERB::Util.html_escape(header), @template.instance_eval{ inline_edit_field(object, field, edit_path, options, &block) })
    end
    
    def empty_cell(n = 1)
      n.times { build_cell }
    end
    
    def empty_cells(n)
      empty_cell(n)
    end
    
    private
    
    def build_cell(head = "", content = "", options = {})
      no_header = options.delete(:no_header)
      header_options = options.delete(:th_options) || {}
      cell_options = options.delete(:td_options) || {}
      header_atts = header_options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "}
      cell_atts = header_options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "}
      shared_atts = options.inject(""){|result, att| result+="#{att.first}=\"#{att.last}\" "}
      html = []
      unless no_header
        header = head.to_s
        header += ":" unless header.blank?
        html << "<th #{header_atts} #{shared_atts}>#{ERB::Util.html_escape(header)}</th>"
      end
      html << "<td #{cell_atts} #{shared_atts}>#{ERB::Util.html_escape(content.to_s)}</td>"
      @cells << html.join("\n").html_safe
    end
  end
  
  def inline_edit_field(object, attribute, url, options = {}, &block)
     field = attribute.to_s
     default_text = h(options.delete(:content) || object.send(field))
     return default_text if options.delete(:disabled)
     method = options.delete(:method) || :put
     if object.errors.include?(field.to_sym)
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
    tb.cells.each_with_index do |cell, i|
      if i % tb.width == 0
        html << "<tr>"
      end 
      html << cell
      if i % tb.width == tb.width - 1
        html << "</tr>"
      end
    end

    html << "</table>"
    html << "</fieldset>"
    
    html.join("\n").html_safe
  end
end