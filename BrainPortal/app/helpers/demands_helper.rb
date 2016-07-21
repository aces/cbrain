
class Hash

      # Turns a hash table into a string suitable to be used
      # as HTML element attributes.
      #
      #   { "colspan" => 3, :style => "color: #ffffff", :x => '<>' }.to_html_attributes
      #
      # will return the string
      #
      #   'colspan="3" style="color: blue" x="&lt;&gt;"'
      def to_html_attributes
        self.inject("") do |result,attpair|
          attname   = attpair[0]
          attvalue  = attpair[1]
          result   += " " if result.present?
          result   += "#{attname}=\"#{ERB::Util.html_escape(attvalue)}\""
          result
        end
      end

end

module DemandsHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def crop_text(text,len = 30)
    return "" if text.blank?
    return h(text) if text.size <= len
    shown = text[0,len] + "..."
    '<span title="'.html_safe + h(text) + '">'.html_safe + h(shown) + '</span>'.html_safe
  end

  def the_organization
    NewAccountOfferings::TheOrganizationShortName
  end

  #Create a checkbox that will select or deselect all checkboxes on the page
  #of class +checkbox_class+.
  #+options+ are just treated as HTML attributes.
  def select_all_checkbox(checkbox_class, options = {})
    options[:class] ||= ""
    options[:class] +=  " select_all"

    options["data-checkbox-class"] = checkbox_class
    atts = options.to_html_attributes

    "<input type='checkbox' #{atts}/>".html_safe
  end

  def admin_user_logged_in?
    if current_user.nil?
      return false
    elsif current_user.has_role?(:admin_user)
      return true
    end
    false
  end
end
