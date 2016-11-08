
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

# Helper methods for tasks views.
module TasksHelper

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  StatesToColor = {
          # Task state name                  => [ color, sort_rank ]
          # --------------------------------    --------------------
          'New'                              => [ "blue",    20 ],
          'Configured'                       => [ "orange",  25 ],
          'Setting Up'                       => [ "blue",    30 ],
          'Queued'                           => [ "blue",    40 ],
          'On CPU'                           => [ "blue",    50 ],
          'On Hold'                          => [ "orange",  45 ],
          'Suspended'                        => [ "orange",  55 ],
          'Data Ready'                       => [ "blue",    60 ],
          'Post Processing'                  => [ "blue",    70 ],
          'Completed'                        => [ "green",   80 ],
          'Terminated'                       => [ "red",     90 ],
          'Failed'                           => [ "red",    100 ], # not an official task status, but used in reports
          'Failed To Setup'                  => [ "red",    135 ],
          'Failed On Cluster'                => [ "red",    165 ],
          'Failed To PostProcess'            => [ "red",    175 ],
          'Failed Setup Prerequisites'       => [ "red",    125 ],
          'Failed PostProcess Prerequisites' => [ "red",    165 ],
          'Recover Setup'                    => [ "purple", 220 ],
          'Recover Cluster'                  => [ "purple", 240 ],
          'Recover PostProcess'              => [ "purple", 260 ],
          'Recovering Setup'                 => [ "purple", 320 ],
          'Recovering Cluster'               => [ "purple", 340 ],
          'Recovering PostProcess'           => [ "purple", 360 ],
          'Restart Setup'                    => [ "blue",   420 ],
          'Restart Cluster'                  => [ "blue",   440 ],
          'Restart PostProcess'              => [ "blue",   460 ],
          'Restarting Setup'                 => [ "blue",   520 ],
          'Restarting Cluster'               => [ "blue",   540 ],
          'Restarting PostProcess'           => [ "blue",   560 ],
          'Preset'                           => [ "black",    0 ], # never seen in interface
          'SitePreset'                       => [ "black",    0 ], # never seen in interface
          'Duplicated'                       => [ "blue",   997 ],
          'Standby'                          => [ "orange", 998 ],
          'TOTAL'                            => [ "black",  999 ], # not an official task status, but used in reports
          'Total'                            => [ "black",  999 ]  # not an official task status, but used in reports
  }


  # Returns a HTML SPAN within which the text of the task +status+ is highlighted in color.
  def colored_status(status)
    return h(status) unless StatesToColor.has_key?(status)
    html_colorize(h(status),StatesToColor[status][0])
  end

  # Returns a colored indicator for the archived status of a task,
  # as returned by the CbrainTask instance method archived_status()
  def colored_archived_status(archived_status = nil)
    return "" if archived_status.blank?
    if archived_status == :userfile
      #html_colorize("&loz;-F".html_safe, 'green')
      html_colorize("&nabla;".html_safe, 'green')
    elsif archived_status == :workdir
      #html_colorize("&loz;-C".html_safe, '#FF6600')
      html_colorize("&loz;".html_safe, '#FF6600')
    else
      html_colorize("?",'red') # should never happen
    end
  end

  def cmp_status_order(status1,status2) #:nodoc:
    info1 = StatesToColor[status1] # can be nil
    info2 = StatesToColor[status2] # can be nil
    return status1 <=> status2 unless info1 && info2 # compare by name
    cmp = (info1[1] <=> info2[1]) # compare their ranks
    return cmp if cmp != 0
    status1 <=> status2 # in case of equality, compare by name again
  end

  # Returns a HTML report snippet with a number of tasks, total size and
  # number of tasks with unknown sizes. Used by the report maker.
  def format_task_size_unk(num_task,tot_size,num_unk)
    t_s_u  = "Tasks: #{num_task}<br/>"
    t_s_u += "Size: #{pretty_size(tot_size)}<br/>"
    t_s_u += num_unk.to_i > 0 ? "Unknown: #{num_unk.to_i}" : "&nbsp;"
    return t_s_u.html_safe
  end

end

