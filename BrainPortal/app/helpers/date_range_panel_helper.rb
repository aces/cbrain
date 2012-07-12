
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

#Helper methods for date range panel.
module DateRangePanelHelper

  Revision_info=CbrainFileRevision[__FILE__]

  #Display a panel in order to select a date range,
  #with relative date and absolute date.
  #You can add on wich datetime attribute you 
  #would perform the filtration.
  def date_range_panel(current_selection = {}, params_name = "date_range", date_attributes = nil)
    
    date_attributes ||= [ [:created_at, "By creation date"], [:updated_at, "By update date"] ]
    
    render :partial => '/shared/date_range_panel', :locals  => {
           :date_attributes           => date_attributes,
           :date_attribute            => ["#{params_name}[date_attribute]",            current_selection["date_attribute"]], 
           :absolute_or_relative_from => ["#{params_name}[absolute_or_relative_from]", current_selection['absolute_or_relative_from']],
           :absolute_or_relative_to   => ["#{params_name}[absolute_or_relative_to]",   current_selection['absolute_or_relative_to']],
           :relative_from             => ["#{params_name}[relative_from]",             current_selection['relative_from']],
           :relative_to               => ["#{params_name}[relative_to]",               current_selection['relative_to']],
           :absolute_from             => ["#{params_name}[absolute_from]",             current_selection['absolute_from']],
           :absolute_to               => ["#{params_name}[absolute_to]",               current_selection['absolute_to']]
        }
  end
  
end
