
#
# CBRAIN Project
#
# Copyright (C) 2008-2023
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

# Helper methods for Quota views.
module QuotasHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Returns a DiskQuota max_bytes in pretty form: 'None allowed' in red, or '126 MB' etc (colored)
  def pretty_quota_max_bytes(quota)
    quota.none_allowed? ? red_if(true, 'None allowed') : colored_pretty_size(quota.max_bytes)
  end

  # Returns a DiskQuota max_files in pretty form: 'None allowed' in red, or just a number
  def pretty_quota_max_files(quota)
    quota.none_allowed? ? red_if(true, 'None allowed') : number_with_commas(quota.max_files)
  end

  # Show a time used, with two components, e.g.
  # "14 seconds", "2 hours and 20 minutes", "5 months and 2 days"
  # When as_limit is true, it will return the
  # string "none allowed" if the value is 0.
  def pretty_quota_cputime(time, as_limit = false)
    return "(Unknown)" if time.blank?
    return red_if(true, 'None allowed') if time <= 0 && as_limit
    return pretty_elapsed(time, :num_components => 2)
  end

  # This method requires the quota object to have
  # populated its internal instance variables, after an
  # active check.
  def pretty_quota_current_cpu_usage(quota)
    week    = quota.cpu_past_week
    month   = quota.cpu_past_month
    ever    = quota.cpu_ever
    week  &&= pretty_elapsed(week,  :num_components => 2)
    month &&= pretty_elapsed(month, :num_components => 2)
    ever  &&= pretty_elapsed(ever,  :num_components => 2)
    week  ||= "(Unknown)"
    month ||= "(Unknown)"
    ever  ||= "(Unknown)"
    "#{week} last week; #{month} last month; #{ever} total"
  end

  # Renders the max number of active tasks
  # in pretty form, e.g. "(Unlimited)", "(None allowed)" or "3 tasks".
  def pretty_max_active_tasks(quota)
    mat = quota.max_active_tasks
    return "(Unlimited)"    if mat.nil?
    return "(None allowed)" if mat < 1
    return "1 task"         if mat == 1
    return "#{mat} tasks"
  end

end
