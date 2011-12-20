
module DataProvidersHelper

  Revision_info=CbrainFileRevision[__FILE__]
  
  # This method reformats a long SSH key text so that it
  # is folded on several lines.
  def pretty_ssh_key(ssh_key)
     return "(None)" if ssh_key.blank?
     return ssh_key
     #pretty = ""
     #while ssh_key != ""
     #  pretty += ssh_key[0,200] + "\n"
     #  ssh_key[0,200] = ""
     #end
     #pretty
  end
  
  # Creates a link called "(info)" that presents as an overlay
  # the set of descriptions for the data providers given in argument.
  def overlay_data_providers_descriptions(data_providers = nil)
    all_descriptions = data_providers_descriptions(data_providers)
    link =
       overlay_content_link("(info)", :enclosing_element => 'span') do
         all_descriptions.html_safe
       end
    link.html_safe
  end

  def data_providers_descriptions(data_providers = nil)
    data_providers ||= DataProvider.find_all_accessible_by_user(current_user)
    paragraphs = data_providers.collect do |dp|
      one_description = <<-"HTML"
        <strong>#{h(dp.name)}</strong>
        <br/>
        <pre class="medium_paragraphs">#{dp.description.blank? ? "(No description)" : h(dp.description.strip)}</pre>
      HTML
    end
    all_descriptions = <<-"HTML"
      <h4>Data Providers Descriptions</h4>
      #{paragraphs.join("")}
    HTML
    all_descriptions.html_safe
  end
  
  def class_param_for_name(name, klass=Userfile) #:nodoc:
    matched_class = klass.descendants.unshift(klass).find{ |c| name =~ c.file_name_pattern }
    
    if matched_class
      "#{matched_class.name}-#{name}"
    else
      nil
    end
  end

end

