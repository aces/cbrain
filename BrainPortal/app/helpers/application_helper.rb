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
     Time.parse(stringtime).localtime.strftime("%Y-%m-%d")
  end

  # Returns a string that represents the amount of elapsed time
  # encoded in +numseconds+ seconds.
  #
  # 0:: "0 seconds"
  # 1:: "1 second"
  # 7272:: "2 hours, 1 minute and 12 seconds"
  def pretty_elapsed(numseconds)
    remain = numseconds.to_i

    return "0 seconds" if remain <= 0

    numweeks = remain / 1.week
    remain   = remain - ( numweeks * 1.week   )

    numdays  = remain / 1.day
    remain   = remain - ( numdays  * 1.day    )

    numhours = remain / 1.hour
    remain   = remain - ( numhours * 1.hour   )

    nummins  = remain / 1.minute
    remain   = remain - ( nummins  * 1.minute )

    numsecs  = remain

    components = [
      [numweeks, "week"],
      [numdays,  "day"],
      [numhours, "hour"],
      [nummins,  "minute"],
      [numsecs,  "second"]
    ]

    components = components.select { |c| c[0] > 0 }

    final = ""

    while components.size > 0
      comp = components.shift
      num  = comp[0]
      unit = comp[1]
      unit += "s" if num > 1
      unless final.blank?
        if components.size > 0
          final += ", "
        else
          final += " and "
        end
      end
      final += "#{num} #{unit}"
    end

    final
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
  
  #Creates a link labeled +name+ to the url +path+ *if* *and* *only* *if*
   #the current user has a role of *admin*. Otherwise, +name+ will be 
   #displayed as static text.
   def link_if_has_access(resource, name, path)
     if resource.can_be_accessed_by?(current_user)
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
