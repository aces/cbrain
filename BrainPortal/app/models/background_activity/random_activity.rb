
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

# A set of fake, debug tests.
#
# The set can contain tests that will succeed, fail, or
# raise an exception, and the tests can take a certain
# mount of time too. The items array look like this:
#
#   [ "2-ok", "3-fail", "19-exc", "4-ok" ... ]
#
# where there number is how long to sleep at the beginning of
# each test, and the keyword is what gets reported to the
# framework.
class BackgroundActivity::RandomActivity < BackgroundActivity

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def pretty_name #:nodoc:
    cnts=self.items.map { |x| x.split('-')[1] }.group_by(&:itself).transform_values { |v| v.size }
    rep=cnts.map { |a,c| "#{c}x #{a}" }.join(", ")
    "Debug: #{rep}"
  end

  # Helper for scheduling a set of tests immediately.
  def self.setup!(user_id, mintime=1.seconds, maxtime=5.seconds, num_successes = 100,num_failures = 0, num_exceptions = 0)
    ba = self.local_new(user_id, []) # items will be filled in setup()
    ba.setup(mintime,maxtime,num_successes,num_failures,num_exceptions)
    ba.save!
    ba
  end

  # Utility to build the items array with a random set of tests.
  def setup(mintime=1.seconds, maxtime=5.seconds, num_successes = 100,num_failures = 0, num_exceptions = 0)
    diff   = maxtime-mintime
    todos  = num_successes.times.map  { (mintime+rand(diff)).to_s + "-ok"   }
    todos += num_failures.times.map   { (mintime+rand(diff)).to_s + "-fail" }
    todos += num_exceptions.times.map { (mintime+rand(diff)).to_s + "-exc"  }
    todos.shuffle!
    self.items = todos
  end

  # The main processing method. Item is a string as
  # described in the class comment above.
  def process(item)
    time,what = item.split("-")
    sleep time.to_i
    return [ true,  "Yeah #{item}" ] if what == 'ok'
    return [ false, "Nope #{item}" ] if what == 'fail'
    raise "Oh darn #{item} exception"
  end

end

