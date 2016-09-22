
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

#Controller helpers related specifically to the views.
module ViewHelpers

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.included(includer) #:nodoc:
    includer.send(:helper_method, *self.instance_methods)
  end

  #################################################################################
  # Date/Time Helpers
  #################################################################################

  # Converts any time string or object to the format 'yyyy-mm-dd hh:mm:ss'.
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
    return "(Unknown)" if pastdate.blank?
    loctime = pastdate.is_a?(Time) ? pastdate : Time.parse(pastdate.to_s)
    locdate = to_localtime(pastdate,what)
    elapsed = pretty_elapsed(Time.now - loctime)
    "#{locdate} (#{elapsed} ago)"
  end

  # Format a byte size for display in the view.
  # Returns the size as one format of
  #
  #   "12.3 Tb"
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
    elsif size >= 1_000_000_000_000
      sprintf("%6.1f Tb", size/1_000_000_000_000.0).strip
    elsif size >= 1_000_000_000
      sprintf("%6.1f Gb", size/    1_000_000_000.0).strip
    elsif size >=     1_000_000
      sprintf("%6.1f Mb", size/        1_000_000.0).strip
    elsif size >=         1_000
      sprintf("%6.1f Kb", size/            1_000.0).strip
    else
      sprintf("%d bytes", size).strip
    end
  end

  # This method returns the same thing as pretty_size,
  # except that the different size orders are colored
  # distinctly. Colors can be overriden in +options+, with
  # the default looking like:
  #   { :gb => 'red', :mb => 'purple', :kb => 'blue', :bytes => nil }
  def colored_pretty_size(size, options = {})
    pretty = pretty_size(size, options)
    if pretty =~ /(\S+) (Tb|Gb|Mb|Kb|bytes)\z/
      val    = Regexp.last_match[1].to_f
      suffix = Regexp.last_match[2].downcase.to_sym
      return html_colorize(pretty, options[:tb].presence    || 'purple') if suffix == :tb
      return html_colorize(pretty, options[:gb100].presence || 'purple') if suffix == :gb && val > 100
      return html_colorize(pretty, options[:gb10].presence  || 'red')    if suffix == :gb && val > 10
      return html_colorize(pretty, options[:gb].presence    || 'orange') if suffix == :gb
      return html_colorize(pretty, options[:mb].presence    || 'green')  if suffix == :mb
      return html_colorize(pretty, options[:kb].presence    || 'blue')   if suffix == :kb
      return html_colorize(pretty, options[:bytes]) if options[:bytes].present?
    end
    pretty # default
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
  # The default +color+ is 'red'.
  # A value of 'default' or nil for +color+ will
  # just return the +text+ without the SPAN.
  def html_colorize(text, color = "red", options = {})
    return text.html_safe if color.blank? || color == 'default'
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
    with_substititions = string.gsub(/(\\|\r?\n|[\n\r'])/) { |m| HTML_FOR_JS_ESCAPE_MAP[m] } # MAKE SURE THIS REGEX MATCHES THE HASH ABOVE!
    with_quotes = "'#{with_substititions}'"
    with_quotes.html_safe
  end

  # Returns a RGB color code '#000000' to '#ffffff'
  # along the edge of the colorwheel. The colors are
  # all thus fully saturated. The color selected
  # will be the one corresponding to where +value+
  # falls along the range between 0 and +max+ .
  #
  # The colorwheel is colored with this orientation:
  #
  # Red axis   = angle   0 degrees
  # Green axis = angle 120 degrees
  # Blue axis  = angle 240 degrees
  #
  # The +options+ control where the values for 0
  # and max will lie on the circle; the default
  # options are:
  #
  #   {
  #     :start  => 240,    # where the value 0 maps to
  #     :length => 240,    # how many degrees along the edge until we reach 'max'
  #     :dir    => :clockwise, # in which direction 'length' degrees goes towards 'max'
  #     :scale  => :log    # whether to scale value logarithmically or linearly
  #   }
  #
  # So this means that by default, a +value+ between 0 and +max+ will
  # select logarithmically a color along the edge from angle 240 down
  # towards angle 0, that is between pure blue and pure red. Purple
  # is thus not available with these defaults.
  #
  # The +unit+ argument is interpreted differently depending on the
  # +scale+ option. When +scale+ is :linear, +value+ will simply
  # be multiplied by +unit+ before being compared to +max+ . When
  # +scale+ is :log, both +value+ and +max+ will be divided by
  # +unit+ before their logs are compared, which is useful when
  # the distribution of values spans large ranges and lots of
  # low values all need to be more or less considered the same.
  def colorwheel_edge_crawl(value, max=100, unit=1, options = {})
    max      = 100 if max.blank?
    unit     = 1   if unit.blank?
    value    = 0   if value < 0
    value    = max if value > max

    start    = options[:start].presence  || 240
    length   = options[:length].presence || 240
    dir      = options[:dir].presence    || :clockwise
    scale    = options[:scale].presence  || :log
    desat    = options[:sat_max_sum].presence # maximum sum of R, G and B chanels (0..765)

    if scale == :log
      percent  = Math.log(1+(value.to_f) / (unit.to_f)) / Math.log((max.to_f) / (unit.to_f))
    else
      percent  = (value.to_f * unit.to_f) / max.to_f
      percent  = 1.0 if percent > 1.0
    end

    if dir == :clockwise
      angle    = start-length*percent # degrees. 0 degrees is along X axis
    else
      angle    = start+length*percent # degrees. 0 degrees is along X axis
    end
    angle += 360 if angle < 0
    angle -= 360 if angle > 360

    r_adist = (angle -   0.0).abs ; r_adist = 360.0 - r_adist if r_adist > 180.0
    g_adist = (angle - 120.0).abs ; g_adist = 360.0 - g_adist if g_adist > 180.0
    b_adist = (angle - 240.0).abs ; b_adist = 360.0 - b_adist if b_adist > 180.0

    r_pdist = r_adist < 60.0 ? 1.0 : r_adist > 120.0 ? 0.0 : 1.0 - (r_adist - 60.0) / 60.0
    g_pdist = g_adist < 60.0 ? 1.0 : g_adist > 120.0 ? 0.0 : 1.0 - (g_adist - 60.0) / 60.0
    b_pdist = b_adist < 60.0 ? 1.0 : b_adist > 120.0 ? 0.0 : 1.0 - (b_adist - 60.0) / 60.0

    red   = r_pdist * 255 # float
    green = g_pdist * 255 # float
    blue  = b_pdist * 255 # float

    if desat.present?
      sum = red + green + blue
      if sum > desat
        div   = desat / sum
        red   =   red * div
        green = green * div
        blue  =  blue * div
      end
    end

    sprintf "#%2.2x%2.2x%2.2x",red,green,blue
  end

end

