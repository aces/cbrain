require 'time'

#Helper methods for all views.
module ApplicationHelper

  Revision_info="$Id$"

  #Sets the text to be displayed in the title bar when a given view is rendered.
  def title(page_title)
    content_for(:title)  { ' - ' + page_title}
  end

  #Converts any time string to the format 'yyyy-mm-dd hh:mm:ss'.
  def to_localtime(stringtime, what = :date)
     loctime = Time.parse(stringtime.to_s).localtime
     if what == :date || what == :datetime
       date = loctime.strftime("%Y-%m-%d")
     end
     if what == :time || what == :datetime
       time = loctime.strftime("%H:%M:%S")
     end
     case what
       when :date
         return date
       when :time
         return time
       when :datetime
         return "#{date} #{time}"
       else
         raise "Unknown option #{what.to_s}"
     end
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

  def pretty_past_date(pastdate, what = :datetime)
    loctime = Time.parse(pastdate.to_s).localtime
    locdate = to_localtime(pastdate,what)
    elapsed = pretty_elapsed(Time.now - loctime)
    "#{locdate} (#{elapsed} ago)"
  end
  
  # Format a byte size for display in the view.
  # Returns the size as one of
  #   12.3 GB
  #   12.3 MB
  #   12.3 KB
  #   123 bytes
  def pretty_size(size)
    if size.blank?
      "unknown"
    elsif size >= 1_000_000_000
      sprintf "%6.1f GB", size/(1_000_000_000 + 0.0)
    elsif size >=     1_000_000
      sprintf "%6.1f MB", size/(    1_000_000 + 0.0)
    elsif size >=         1_000
      sprintf "%6.1f KB", size/(        1_000 + 0.0)
    else
      sprintf "%d bytes", size
    end 
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
  #the current user has a role of *admin* or <b>site manager</b>. Otherwise, +name+ will be 
  #displayed as static text.
  def link_if_manager(name, path)
    if check_role(:admin) || check_role(:site_manager)
      link_to(name, path)
    else
      name
    end
  end
  
  #Creates a link labeled +name+ to the url +path+ *if* *and* *only* *if*
   #the current user has access to +resource+. Otherwise, +name+ will be 
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
     return ssh_key
     pretty = ""
     while ssh_key != ""
       pretty += ssh_key[0,200] + "\n"
       ssh_key[0,200] = ""
     end
     pretty
  end
  
  def set_selected(param_controller, current_item)
    if(current_item == :user_site_show && 
      params[:controller].to_s == 'sites' &&
      params[:action].to_s == 'show' &&
      params[:id].to_s == current_user.site_id.to_s)
      'id="selected"'
    elsif(param_controller.to_s == current_item.to_s)
      'id="selected"'
    else
      'id="unselected"'
    end
  end
  
  #Set direction for resource list sorting
  def set_dir_old(current_order, prev_order, sort_order)
    if(current_order.to_s == prev_order.to_s)
      sort_order == 'DESC' ? '' : 'DESC'
    end
  end
  
  #Set direction for resource list sorting
  def set_dir(current_order, sort_params)
    return unless sort_params
    prev_order = sort_params["order"]
    sort_order = sort_params["dir"]
    
    if(current_order.to_s == prev_order.to_s)
      sort_order == 'DESC' ? '' : 'DESC'
    end
  end
  
  #Set arrow icon for ordering of userfiles. I.e. display a red arrow
  #next to the header of a given column in the Userfile index table *if*
  #that column is the one currently determining the order of the file.
  #
  #Toggles the direction of the arrow depending on whether the order is 
  #ascending or descending.
  def set_order_icon(location, current_order, current_dir = nil)
    return if current_order == nil
    
    #order, direction = session_order.sub("type, ", "").split
    
    return unless location == current_order
    
    if location == 'userfiles.lft' || location == 'drmaa_tasks.launch_time DESC, drmaa_tasks.created_at'
      icon = '<font color="Red">&nbsp;&bull;</font>'
    else
      icon = '<font color="Red">&nbsp;&dArr;</font>'
      if current_dir == 'DESC'
        icon = '<font color="Red">&nbsp;&uArr;</font>'
      end
    end
    
    icon
  end
  
  #Reduces a string to the length specified by +length+.
  def crop_text_to(length, string)
    return "" if string.blank?
    if string.length <= length
      string
    else
      string[0,length-3] + "..."
    end
  end
  
  def parse_message(message)
    arr = message.split(/(\[\[.*?\]\])/)
    arr.each_with_index do |str,i|
      if i % 2 == 0
        arr[i] = arr[i]
      else
        arr[i].sub! /\[\[(.+?)\]\[(.+?)\]\]/, "<a href='\\2' class='action_link'>\\1</a>"
      end
    end   
    
    arr.join
  end
  
  def add_tool_tip(message, &block)
    content = capture(&block)
    
    if message.blank?
      concat(content)
      return
    end
    concat("<span title='#{message}'>")
    concat(content)
    concat("</span>")
  end
 




  ############################################################
  #                                              
  # This class is used to create a tabs          
  # the TabBar.tab creates individual tabs       
  # You can give TabBar.tab a partial or         
  # simply a block to define the content         
  #                                              
  # To initialize, provide it with a                         
  # reference to ActionView::Helpers::CaputreHelper::caputre 
  # and ActionView::TamplateHelperHandler::render                                                         
  #############################################################
  class TabBar
    
    def initialize(capture,render)
      @tab_titles = "<ul>\n"
      @tab_divs = ""
      @capture = capture #HACK ALERT:This is the the capture method given to the object on creation, 
                         #since this class can't access 
                         #Things from the enclosing module
      @render = render   #HACK ALERT: same thing as the capture, it's the render from the surrounding module
                         #horrible code, don't attempt at home
    end

    attr_reader :tab_titles, :tab_divs
    attr_writer :tab_titles #Making this writable because I need to add a </ul> to it. 

    
    #This creates an individual tab, it either takes a block and/or a partial as an option (:partial => "partial")
    def tab(options, &block)
      @tab_titles += "<li "
      if options[:class]
        @titles +="class='##{options[:class]}' "
      end
      @tab_titles +="><a href='##{options[:name]}'>#{options[:name]}</a></li>"
      

      #########################################
      #tab content div.                       #
      #                                       #
      #This can be either a partial or a block#
      #########################################
      @tab_divs += "<div id=#{options[:name]}>\n" 
      if options[:partial]
       @tab_divs += @render.call( :partial => options[:partial])
      end
      if block
        @tab_divs += @capture.call(&block)
      end
      @tab_divs += "</div>\n"      
    end
    
  end



  def tab_bar(&block)

    foo="nothing" #can't have bar without foo (what's the point of comments if there's no jokes ;p)

    #THIS LINE CONTAINS METAPROGRAMMING
    #The TabBar class can't access the capture method and the render method so we are passing them
    #in as a initialization variable
    #This is obviously horrible coding practice 
    bar=TabBar.new(method(:capture),method(:render))
    

    capture(bar,&block)
    bar.tab_titles +="</ul>"
    concat("<div class='tabs'>")
    concat(bar.tab_titles)
    concat(bar.tab_divs)
    concat("</div>")
  end
  
  def inplace_edit_field(options)
    name = options[:name]
    label = options[:label]
    initial = options[:initial_value] || ""
    "<div class=\"inline_edit_field\">"+
      "<span>"+
        "#{label}:  "+
        "<span class=\"current_text\">#{initial}</span>"+
        "<input name=\"#{name}\" />"+
      "</span>" +
      "<a class=\"inplace_edit_field_save\" >save</a>"+
    "</div>" 
    
  end
  def overlay_dialog_with_button(options,&block)
    partial = options[:partial]
    name = options[:name]
    button_text = options[:button_text]
    if partial
      content = render partial
    else
      content = capture(&block)
    end
    concat("<div class=\"overlay_dialog\">")
    concat("<div class=\"dialog\" id=\"#{name}\">")
    concat(content)
    concat("</div>")
    concat("<a class=\"dialog_button\">#{button_text}</a>")
    concat("</div>")
  end
 

end
