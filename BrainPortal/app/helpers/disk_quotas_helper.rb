
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

# Helper methods for Disk Quota views.
module DiskQuotasHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Returns a DiskQuota max_bytes in pretty form: 'None allowed' in red, or '126 MB' etc (colored)
  def pretty_quota_max_bytes(quota)
    quota.none_allowed? ? red_if(true, 'None allowed') : colored_pretty_size(quota.max_bytes)
  end

  # Returns a DiskQuota max_files in pretty form: 'None allowed' in red, or just a number
  def pretty_quota_max_files(quota)
    quota.none_allowed? ? red_if(true, 'None allowed') : quota.max_files
  end

end
