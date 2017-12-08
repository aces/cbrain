
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

# Automatic Parallelizer Task
# The CBRAIN framework uses this to automatically
# parallelize other tasks. It can also be used
# by tasks to parallelize their own subtasks.
class CbrainTask::Parallelizer < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.properties #:nodoc:
    {
      :no_presets => true
    }
  end

  # Disabled, not necessary, and costly a little.
  # I want to keep the code around for future use, though.
  #def pretty_name #:nodoc:
  #  prereqs      = self.prerequisites  || {}
  #  for_setup    = prereqs[:for_setup] || {}
  #  ttids        = for_setup.keys   #  [ "T123", "T343" etc ]
  #  tids         = ttids.map { |ttid| ttid[1,999].to_i }
  #  prereq_tasks = CbrainTask.where(id: tids)
  #  grouped      = prereq_tasks.group_by(&:name)
  #  summary      = ""
  #  grouped.each do |name,tasklist|
  #    summary += ", " if ! summary.blank?
  #    summary += "#{name} x #{tasklist.size}"
  #  end
  #  "Parallelizer (#{summary})"
  #end

end

