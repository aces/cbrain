
#
# CBRAIN Project
#
# Copyright (C) 2008-2024
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

# Helper methods for background activities views.
module BackgroundActivitiesHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  StatesToColor = {
    # State name                       => color
    # --------------------------------    --------------------
    'InProgress'                       => "blue",
    'Completed'                        => "green",
    'PartiallyCompleted'               => "orange",
    'Failed'                           => "red",
    'InternalError'                    => "red",
    'Suspended'                        => "purple",
    'SuspendedScheduled'               => "purple",
    'Scheduled'                        => "lime",
    'Cancelled'                        => "fuchsia",
    'CancelledScheduled'               => "fuchsia",
  }


  # Returns a HTML SPAN within which the text of the task +status+ is highlighted in color.
  def colored_bac_status(status)
    return h(status) unless StatesToColor.has_key?(status)
    html_colorize(h(status.underscore.humanize),StatesToColor[status])
  end

end

