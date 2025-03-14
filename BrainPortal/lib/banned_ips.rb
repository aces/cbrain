
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

# Utility class to persistently manage a list
# of banned IP addresses within a Rails app.
# All methods are class methods.
class BannedIps

  MAIN_LIST_KEY = "banned_ips_array"
  BAN_PREFIX    = "ban_ip_"
  BAN_TIME      = 2.weeks

  # Return an array of the currently banned IPs
  def self.banned_ips
    list  = Rails.cache.fetch(MAIN_LIST_KEY, :expires_in => BAN_TIME) { [] }
    list2 = list.select { |ip| banned_ip?(ip) }
    return list if list.size == list2.size
    Rails.cache.write(MAIN_LIST_KEY, list2, :expires_in => BAN_TIME)
    return list2
  end

  # Add an IP to the ban list
  def self.ban_ip(ip, time = BAN_TIME)
    current_list = banned_ips
    current_list |= [ ip ]
    current_list.sort!
    Rails.cache.write(MAIN_LIST_KEY, current_list, :expires_in => time)
    Rails.cache.write("#{BAN_PREFIX}#{ip}",true,   :expires_in => time)
    time
  end

  # Remove an IP to the ban list
  def self.unban_ip(ip)
    Rails.cache.delete("#{BAN_PREFIX}#{ip}") # true/nil
  end

  # Query an IP and return true if it is banned
  def self.banned_ip?(ip)
    Rails.cache.fetch("#{BAN_PREFIX}#{ip}") # true/nil
  end

end
