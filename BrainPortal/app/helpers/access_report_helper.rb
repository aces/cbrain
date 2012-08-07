
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

# View helpers for creating access reports.
module AccessReportHelper
  
  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:
  
  # Produces a pretty times symbol (used to show unavailable ressources)
  def times_icon(color="red")
    "<span style=\"color:#{color}\" class=\"bold_icon\">&times;</span>".html_safe
  end

  # Produces a pretty o symbol (used to show available ressources)
  def o_icon(color="green")
    "<span style=\"color:#{color}\" class=\"bold_icon\">&#927;</span>".html_safe
  end

  # Produces a pretty symbol for hidden resources
  def hidden_icon(color="purple")
    "<span style=\"color:#{color}\" class=\"bold_icon\">H</span>".html_safe
  end

  # Produces a centered legend 
  def center_legend(title, legend_a)
    legend  = "<center>"
    legend += "#{title}&nbsp;&nbsp;&nbsp;&nbsp;" if title
    legend_a.each do |pair|
      symbol = pair[0]
      label  = pair[1]
      legend += "#{symbol}:&nbsp#{label}&nbsp;&nbsp;&nbsp;&nbsp;"
    end
    legend += "</center>\n"
    return legend.html_safe
  end
  
end
