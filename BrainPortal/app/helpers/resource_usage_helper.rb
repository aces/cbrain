
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

# Helper methods for resource usage views.
module ResourceUsageHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Prints a pretty colorized value for the ResourceUsage;
  # Time: "1234 seconds (20 minutes and 34 seconds)"
  # Space: "+ 123 kb" or "- 123 kb" etc
  # Returns an empty string if the value is 0
  def pretty_resource_usage_value(ru)
    val = ru.value
    return "" if val.blank?
    return "" if ru == 0
    if ru.is_a?(TimeResourceUsage)
      report  = pluralize(val, "second")
      report += " (" + pretty_elapsed(val, :num_components => 2) + ") " if val > 59
      return report
    end
    if val >= 0
       ('<span style="color: green">&plus;</span>&nbsp;' + colored_pretty_size(val) ).html_safe
    else
       ('<span style="color: red">&minus;</span>&nbsp;'  + colored_pretty_size(-val)).html_safe
    end
  end

end

