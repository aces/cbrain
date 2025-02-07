
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

# This file contains miscelleneous reports that can be generated
# in the Rails console.

# Active transfers report
def trans
   no_log do
     SyncStatus.where(:status => ["ToCache","ToProvider"]).all.each do |ss|
       file = ss.userfile
       what = ss.remote_resource
       dir  = (ss.status == "ToCache") ? "\342\226\274" : "\342\226\262" # UTF8 down triangle, up triangle
       printf "%12.12s %s %-12.12s (%9s) [%8.8s] \"%s\" for %s\n",
               what.name, dir, file.data_provider.name,
               pretty_size(file.size), file.user.login, file.name,
               pretty_elapsed(Time.now - ss.updated_at, :num_components => 3)
     end
   end
   true
end

# Active tasks
def acttasks(tasks = CbrainTask.active.all)
  no_log do
    list1 = tasks.group_by(&:batch_id).map do |batch_id,tasklist|
      tasklist.sort! { |a,b| (a.rank || 0) <=> (b.rank || 0) || a.id <=> b.id }
      first = tasklist[0]
      result = { :a_task   => first.name_and_bourreau, :b_user => first.user.login,
                 :c_types => "", :d_statuses => "" }
      by_types  = tasklist.hashed_partitions { |t| t.type.demodulize }
      by_status = tasklist.hashed_partitions { |t| t.status }
      result[:c_types]    = by_types.map  { |t,list| "#{list.size} x #{t}" }.join(", ") unless by_types.size == 1
      result[:d_statuses] = by_status.map { |s,list| "#{list.size} x #{s}" }.join(", ")
      result
    end

    # Remove column c_types if it's empty everywhere
    if list1.all? { |struct| struct[:c_types].blank? }
      list1.each  { |struct| struct.delete(:c_types) }
    end

    # Remove duplicates from list1 and count them
    seen={}
    list2 = list1.select { |r| seen[r] ||= 0 ; seen[r] += 1 ; seen[r] == 1 }
    list2.each { |r| r[:_] = seen[r] } # assign counts

    # Hirb helper for printing pretty table
    table list2, :unicode => true
  end

  true
end

# Last connected users.
# Try "last -20", just like in a shell!
# Also supported:
#   last -20, loginname
#   last loginname
def last(lim=20, user=nil)
  # Silly args parser/shifter
  if lim.to_s !~ /^-?\d+$/
    user ||= lim.to_s # shift
    lim=20
  end
  table LargeSessionInfo
        .order("large_session_infos.updated_at desc")
        .joins(:user)
        .where(user.blank? ? {} : { 'users.login' => user.to_s })
        .select( %w( users.login
                     users.id
                     large_session_infos.active
                     large_session_infos.updated_at
                     large_session_infos.data
                   )
        )
        .limit(lim.abs)
        .map { |x|
          { :a_id       => x.id,
            :b_login    => x.login,
            :c_from     => x.data[:guessed_remote_host],
            :logged?    => x.active? ? 'in' : 'out',
            :x_activity => pretty_past_date(x.updated_at, :datetime, 2),
          }
        },
        :unicode => true
end

(CbrainConsoleFeatures ||= []) << <<FEATURES
========================================================
Feature: Reports
========================================================
  trans    : report of active transfers between resources and DP
  acttasks : report active tasks
  last [n] : last connected users (n = limit, default 20)
FEATURES

