
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

module DateRangeRestriction

  #Checks consistence of values for filtration by date.
  #For exemple if filtration by absolute_date_from will be process 
  #then the absolute date 'from' is required. 
  #Returns an empty string if everything is good, 
  #else returns an explicit message in order to know what's wrong.
  #Can be used with partial shared/date_range
  def check_filter_date(date_attribute,absolute_or_relative_from,absolute_or_relative_to,absolute_from,absolute_to,relative_from,relative_to)
    return "" if date_attribute.blank?
    
    if (absolute_or_relative_from == "absolute") && absolute_from.blank?
      return "You should enter an absolute 'from' date or de-select radio button"
    end
	  
    if (absolute_or_relative_to == "absolute") && absolute_to.blank?
      return "You should enter an absolute 'to' date or de-select radio button"
    end

    if (absolute_or_relative_to == "relative") && (absolute_or_relative_from == "relative") && (relative_from == relative_to)
      return "You should choose 2 differents relatives dates"
    end

    return ""
  end
  
  #Add date range to scope.
  #We need an initial scope, name of table, 2 booleans
  #(one to know if 'date_from' is an absolute date (mode_is_absolute_from),
  #one to know if 'date_to' is an absolute date    (mode_is_absolute_to)),
  #absolute date from and absolute date to (format is dd/mm/yyyy),
  #relative date from and relative date to (in second), 
  #and finally a string 'updated_at' or 'created_at' to know
  #if filtration need to be perform on created_at or updated_at
  def add_condition_to_scope(scope, table_name, mode_is_absolute_from, mode_is_absolute_to, absolute_from, absolute_to, relative_from, relative_to, date_at)
    
    return scope if date_at !~ /^(updated_at|created_at)$/

    offset = Time.now.in_time_zone.utc_offset.seconds

    if mode_is_absolute_from.present?
      user_start = DateTime.parse(absolute_from)
    else
      user_start = Time.now - relative_from.to_i
    end

    if mode_is_absolute_to.present?
      user_end = DateTime.parse(absolute_to)
    else
      user_end = Time.now - relative_to.to_i
    end

    need_switching      = user_start > user_end
    user_start,user_end = user_end,user_start if need_switching
    user_end            = user_end + 1.day    if ( !need_switching && mode_is_absolute_to ) || (need_switching && mode_is_absolute_from)

    scope = scope.scoped(:conditions  => ["#{table_name}.#{date_at} >= ?", user_start - offset])
    scope = scope.scoped(:conditions  => ["#{table_name}.#{date_at} <= ?", user_end   - offset])
    
    scope

  end

  
end

