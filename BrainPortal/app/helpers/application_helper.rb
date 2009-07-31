require 'time'

#Helper methods for all views.
module ApplicationHelper

  Revision_info="$Id$"

  #Sets the text to be displayed in the title bar when a given view is rendered.
  def title(page_title)
    content_for(:title)  { ' - ' + page_title}
  end

  #Converts any time string to the format 'yyyy-mm-dd hh:mm:ss'.
  def to_localtime(stringtime)
     Time.parse(stringtime).localtime.strftime("%Y-%m-%d %H:%M:%S")
  end
  
  #Creates a link labeled +name+ to the url +path+ *if* *and* *only* *if*
  #the current user has a role of *admin*. Otherwise, +name+ will be 
  #displayed as static text.
  def link_if_admin(name, path)
    if check_role(:admin)
      link_to(name, path)
    else
      name
    end
  end

  # This method reformats a long SSH key text so that it
  # is folded on several lines.
  def pretty_ssh_key(ssh_key)
     pretty = ""
     while ssh_key != ""
       pretty += ssh_key[0,50] + "\n"
       ssh_key[0,50] = ""
     end
     pretty
  end

end
