
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

  # Returns a colorized pretty version of the "repeat" keyword.
  def bac_pretty_repeat(repeat)
    return "" if repeat.blank?
    return html_colorize("One shot","black") if repeat == "one_shot"
    if repeat =~ /start\+(\d+)/
      mins = Regexp.last_match[1]
      return html_colorize("Every #{pretty_elapsed(60*mins.to_i)}","orange")
    end
    if repeat =~ /(\S+)@(\d\d:\d\d)/
      keyword = Regexp.last_match[1].capitalize
      time    = Regexp.last_match[2]
      keyword += "s" if keyword =~ /monday|tuesday|wednesday|thursday|friday|saturday|sunday/i
      color = (keyword == "Tomorrow") ? "green" : "blue"
      keyword = "Daily" if keyword == "Tomorrow"
      return html_colorize("#{keyword} at #{time}",color)
    end
    html_colorize(repeat,"red") # unknown?!?
  end

end

