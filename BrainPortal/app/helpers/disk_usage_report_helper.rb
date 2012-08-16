
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

# View helpers for creating disk usage reports.
module DiskUsageReportHelper
  
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:
  
  # Returns a RGB color code '#000000' to '#ffffff'
  # for disk sizes; the values are all fully saturated
  # and move about the colorwheel from pure blue
  # to pure red along the edge of the wheel.
  # See the helper colorwheel_edge_crawl() for
  # more information.
  def size_to_color(size,max=500_000_000_000,unit=1_000_000)
    colorwheel_edge_crawl(size, max.presence || 500_000_000_000, unit.presence || 1_000_000,
      :start  => 240,
      :length => 240,
      :dir    => :clockwise,
      :scale  => :log
    )
  end

  # Produces a colored square
  def colored_square(color)
    span  = "<span class=\"display_cell dp_disk_usage_color_span\">"
    span += "  <div class=\"dp_disk_usage_color_block\" style=\"background: #{color}\"></div>"
    span += "</span>"
    span.html_safe
  end

  # Produces cell contain in order to display colored_square 
  # and text side by side.
  def disk_space_info_display(size, max_size=500_000_000_000, unit=1_000_000, &block)
    text = capture(&block)

    cellcolor = size_to_color(size || 0, max_size, unit)
    contain   = "<span class=\"display_cell dp_disk_usage_color_span\">"
    contain  += "<div class=\"dp_disk_usage_color_block\" style=\"background: #{cellcolor}\"></div>"
    contain  += "</span>"
    contain  += "<span class=\"display_cell no_wrap\">"
    contain  += "#{text}"
    contain  += "</span>"

    return contain.html_safe
  end
  
  # Produces a legend for disk usage reports
  def disk_usage_legend
    legend = <<-HTML_LEGEND
    <center>
      <span class="display_cell">
        #{disk_space_info_display(              0,500_000_000_000,1_000_000) {     "None" }}
        #{disk_space_info_display(     10_000_000,500_000_000_000,1_000_000) {    "10 Mb" }}
        #{disk_space_info_display(    100_000_000,500_000_000_000,1_000_000) {   "100 Mb" }}
        #{disk_space_info_display(  1_000_000_000,500_000_000_000,1_000_000) {     "1 Gb" }}
        #{disk_space_info_display( 10_000_000_000,500_000_000_000,1_000_000) {    "10 Gb" }}
        #{disk_space_info_display(100_000_000_000,500_000_000_000,1_000_000) {   "100 Gb" }}
        #{disk_space_info_display(500_000_000_000,500_000_000_000,1_000_000) { "> 500 Gb" }}
      </span>
    </center>
    HTML_LEGEND
    return legend.html_safe
  end
  
end
