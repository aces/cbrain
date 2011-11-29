module ViewHelpers
  
  def self.included(includer) #:nodoc:
    includer.send(:helper_method, *self.instance_methods)
  end
  
  #################################################################################
  # Date/Time Helpers
  #################################################################################
  
  #Converts any time string or object to the format 'yyyy-mm-dd hh:mm:ss'.
  def to_localtime(stringtime, what = :date)
     loctime = stringtime.is_a?(Time) ? stringtime : Time.parse(stringtime.to_s)
     loctime = loctime.in_time_zone # uses the user's time zone, or the system if not set. See activate_user_time_zone()
     if what == :date || what == :datetime
       date = loctime.strftime("%Y-%m-%d")
     end
     if what == :time || what == :datetime
       time = loctime.strftime("%H:%M:%S %Z")
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
  def pretty_elapsed(numseconds,options = {})
    remain    = numseconds.to_i
    is_short  = options[:short]
    
    
    return "0 seconds" if remain <= 0

    numyears = remain / 1.year.to_i
    remain   = remain - ( numyears * 1.year.to_i   )
    
    nummos   = remain / 1.month
    remain   = remain - ( nummos * 1.month   )

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
      [numyears, is_short ? "y" : "year"],
      [nummos,   is_short ? "mo" : "month"],
      [numweeks, is_short ? "w" : "week"],
      [numdays,  is_short ? "d" : "day"],
      [numhours, is_short ? "h" : "hour"],
      [nummins,  is_short ? "m" : "minute"],
      [numsecs,  is_short ? "s" : "second"]
    ]

    
   components = components.select { |c| c[0] > 0 }
   components.pop   while components.size > 0 && components[-1] == 0 
   components.shift while components.size > 0 && components[0]  == 0 
   
    if options[:num_components]
      while components.size > options[:num_components]
        components.pop
      end
    end

    final = ""

    while components.size > 0
      comp = components.shift
      num  = comp[0]
      unit = comp[1]
      if !is_short
        unit += "s" if num > 1
        unless final.blank?
          if components.size > 0
            final += ", "
          else
            final += " and "
          end
        end
      end
      final += !is_short ? "#{num} #{unit}" : "#{num}#{unit}"
    end

    final
  end

  # Returns +pastdate+ as as pretty date or datetime with an
  # amount of time elapsed since then expressed in parens
  # just after it, e.g.,
  #
  #    "2009-12-31 11:22:33 (3 days 2 hours 27 seconds ago)"
  def pretty_past_date(pastdate, what = :datetime)
    loctime = pastdate.is_a?(Time) ? pastdate : Time.parse(pastdate.to_s)
    locdate = to_localtime(pastdate,what)
    elapsed = pretty_elapsed(Time.now - loctime)
    "#{locdate} (#{elapsed} ago)"
  end
  
  # Format a byte size for display in the view.
  # Returns the size as one format of
  #
  #   "12.3 Gb"
  #   "12.3 Mb"
  #   "12.3 Kb"
  #   "123 bytes"
  #   "unknown"     # if size is blank
  #
  # Note that these are the DECIMAL SI prefixes.
  #
  # The option :blank can be given a
  # string value to return if size is blank,
  # instead of "unknown".
  def pretty_size(size, options = {})
    if size.blank?
      options[:blank] || "unknown"
    elsif size >= 1_000_000_000
      sprintf("%6.1f Gb", size/(1_000_000_000.0)).strip
    elsif size >=     1_000_000
      sprintf("%6.1f Mb", size/(    1_000_000.0)).strip
    elsif size >=         1_000
      sprintf("%6.1f Kb", size/(        1_000.0)).strip
    else
      sprintf("%d bytes", size).strip
    end 
  end

  # Returns one of two things depending on +condition+:
  # If +condition+ is FALSE, returns +string1+
  # If +condition+ is TRUE, returns +string2+ colorized in red.
  # If no +string2+ is supplied, then it will be considered to
  # be the same as +string1+.
  # Options can be use to specify other colors (as :color1 and
  # :color2, respectively)
  #
  # Examples:
  #
  #     red_if( ! is_alive? , "Alive", "Down!" )
  #
  #     red_if( num_matches == 0, "#{num_matches} found" )
  def red_if(condition, string1, string2 = string1, options = { :color2 => 'red' } )
    if condition
      color = options[:color2] || 'red'
      string = string2 || string1
    else
      color = options[:color1]
      string = string1
    end
    return color ? html_colorize(ERB::Util.html_escape(string),color) : ERB::Util.html_escape(string)
  end

  # Returns a string of text colorized in HTML.
  # The HTML code will be in a SPAN, like this:
  #   <SPAN STYLE="COLOR:color">text</SPAN>
  # The default color is 'red'.
  def html_colorize(text, color = "red", options = {})
    "<span style=\"color: #{color}\">#{ERB::Util.html_escape(text)}</span>".html_safe
  end

  # Calls the view helper method 'pluralize'
  def view_pluralize(*args) #:nodoc:
    ApplicationController.helpers.pluralize(*args)
  end
  
  HTML_FOR_JS_ESCAPE_MAP = {
  #  '"'     => '\\"',    # wrong, we leave it as is
  #  '</'    => '<\/',    # wrong too
    '\\'    => '\\\\',
    "\r\n"  => '\n',
    "\n"    => '\n',
    "\r"    => '\n',
    "'"     => "\\'"
  }

  # Escape a string containing HTML code so that it is a valid
  # javascript constant string; the string will be quoted
  # with single quotes (') on each end.
  # There exists a helper in module ActionView::Helpers::JavaScriptHelper
  # called escape_javascript(), but it also escapes some character sequences
  # that create problems within Javascript code intended to substitute
  # HTML in a document.
  def html_for_js(string)
    # "'" + string.gsub("'","\\\\'").gsub(/\r?\n/,'\n') + "'"
    return "''".html_safe if string.nil? || string == ""
    with_substititions = string.gsub(/(\\|\r?\n|[\n\r'])/) { HTML_FOR_JS_ESCAPE_MAP[$1] } # MAKE SURE THIS REGEX MATCHES THE HASH ABOVE!
    with_quotes = "'#{with_substititions}'"
    with_quotes.html_safe
  end
end