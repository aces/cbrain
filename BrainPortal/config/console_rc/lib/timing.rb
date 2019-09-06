
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

# This file contains miscelleneous timing helper that can be invoked
# in the Rails console.

# hl == how long
def hl
  unless block_given?
    puts "Usage: hl { block }"
    return false
  end
  s = Time.now
  r = yield
  f = Time.now
  puts "Time taken: #{f-s} seconds"
  r
end

# hls == how long in SQL
def hls(sql)
  hl do
    sql = sql.to_sql if sql.respond_to?(:to_sql)
    r = ActiveRecord::Base.connection.execute(sql)
    table r
    true
  end
end

(CbrainConsoleFeatures ||= []) << <<FEATURES
========================================================
Feature: Timing helpers
========================================================
  hl  { block } : reports how long to run 'block'
  hls sql       : reports how long to run SQL 'sql'
FEATURES

