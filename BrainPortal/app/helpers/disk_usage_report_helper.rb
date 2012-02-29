
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

module DiskUsageReportHelper
  
  Revision_info=CbrainFileRevision[__FILE__]
  
  # Returns a RGB color code '#000000' to '#ffffff'
  # for size; the values are all fully saturated
  # and move about the colorwheel from pure blue
  # to pure red along the edge of the wheel. This
  # means no white or black or greys is ever returned
  # by this method. Max indicate to which values
  # and above the pure 'red' results corresponds to.
  # Red axis   = angle   0 degrees
  # Green axis = angle 120 degrees
  # Blue axis  = angle 240 degrees
  # The values are spread from angle 240 down towards angle 0
  def size_to_color(size,max=nil,unit=1)
    max      = 500_000_000_000 if max.nil?
    size     = max if size > max
    percent  = Math.log(1+(size.to_f) / (unit.to_f)) / Math.log((max.to_f) / (unit.to_f))
    angle    = 240-240*percent # degrees

    r_adist = (angle -   0.0).abs ; r_adist = 360.0 - r_adist if r_adist > 180.0
    g_adist = (angle - 120.0).abs ; g_adist = 360.0 - g_adist if g_adist > 180.0
    b_adist = (angle - 240.0).abs ; b_adist = 360.0 - b_adist if b_adist > 180.0

    r_pdist = r_adist < 60.0 ? 1.0 : r_adist > 120.0 ? 0.0 : 1.0 - (r_adist - 60.0) / 60.0
    g_pdist = g_adist < 60.0 ? 1.0 : g_adist > 120.0 ? 0.0 : 1.0 - (g_adist - 60.0) / 60.0
    b_pdist = b_adist < 60.0 ? 1.0 : b_adist > 120.0 ? 0.0 : 1.0 - (b_adist - 60.0) / 60.0

    red   = r_pdist * 255
    green = g_pdist * 255
    blue  = b_pdist * 255

    sprintf "#%2.2x%2.2x%2.2x",red,green,blue
  end

  
  # Produces a colored square (used to show )
  def colored_square(color)
    span  = "<span class=\"display_cell dp_disk_usage_color_span\">"
    span += "  <div class=\"dp_disk_usage_color_block\" style=\"background: #{color}\"></div>"
    span += "</span>"
    span.html_safe
  end

  # Produces cell contain in order to display colored_square 
  # and text side by side
  def disk_space_info_display(size, max_size, unit, &block)
    text = capture(&block)

    cellcolor = size_to_color(size || 0, max_size, unit)
    contain   = "<span class=\"display_cell dp_disk_usage_color_span\">"
    contain  += "<div class=\"dp_disk_usage_color_block\" style=\"background: #{cellcolor}\"></div>"
    contain  += "</span>"
    contain  += "<span class=\"display_cell\">"
    contain  += "#{text}"
    contain  += "</span>"

    return contain.html_safe
  end
  
  # Produces a legend for disk usage reports
  def disk_usage_legend
    legend  = "<center>"
    low_cell_color  = size_to_color(0)
    high_cell_color = size_to_color(100,100)
    
    legend += "<span class=\"display_cell\">"
    legend += "#{colored_square(size_to_color(0))}"
    legend += "<strong class=\"display_cell\">	&#8594; </strong>" 
    legend += "#{colored_square(size_to_color(100,100))}"
    legend += "</span>"
    legend += "<br/>"
    legend += "Low to High disk usage"
    legend += "</center>"
    return legend.html_safe
  end
  
end
