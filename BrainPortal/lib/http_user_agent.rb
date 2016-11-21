
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

#
# Parses a HTTP user agent string, trying to guess some of
# its most useful parts.
#
# This code was written by Pierre Rioux and was inspired by
# the code of two other projects:
#
# user-agent.git by Douglas Meyer:
#   https://github.com/visionmedia/user-agent
#
# parse-user-agent.git by Jackson Miller
#   https://github.com/jaxn/parse-user-agent.git
#
# None of these really satisfied me, so I picked and chose
# pieces of both to write my own. -- Pierre.
#
# Usage:
#
#   parser = HttpUserAgent.new
#   parser.parse(ua_string)
#   print parser.browser_name
#
# Quicker API:
#
#   parsed = HttpUserAgent.new(ua_string)
#
class HttpUserAgent

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  attr_accessor :browser_name, :browser_version,
                :os_name, :os_version, :os_arch

  def initialize(user_agent_string = "") #:nodoc:
    self.parse(user_agent_string) unless user_agent_string.blank?
    self
  end

  # Tries to parse the given http user agent string into its
  # components, and fills the values for the attr_accessors
  # defined in the class.
  def parse(user_agent_string)

    self.reset

    @full_ua = user_agent_string

    # Pre-processing
    adj_ua = user_agent_string
    adj_ua.gsub!(/(MSIE|Opera)\s+([\d\.]+)/,'\1/\2')

    # Identifies all substrings in format 'abcd/1234'
    keyvals = {}
    lastname = ""
    adj_ua.split(/[\s;()]+/).each do |comp|
      next unless comp =~ /\A(\S+)\/(\S+)\z/
      name  = Regexp.last_match[1]
      value = Regexp.last_match[2]
      next if keyvals.has_key?(name.downcase) # first match has priority
      keyvals[name.downcase] = value
      lastname = name
    end

    # Identify the browser
    priority_list = [ 'WebPositive', 'Konqueror',
                      'Edge', # stupid microsoft pretends to be safari and chrome too
                      'Chrome', 'Safari', 'Opera',
                      'SeaMonkey', 'Firefox', 'MSIE',
                      'CbrainPerlAPI', 'CbrainRubyAPI', 'CbrainJavaAPI', lastname ]
    priority_list.each do |name|
      lcname = name.downcase
      next unless keyvals.has_key?(lcname)
      self.browser_name    = name
      self.browser_version = keyvals[lcname]
      break
    end

    # Identify the OS and architecture
    self.os_name = case adj_ua # case statement mostly from D. Meyer's code, adjusted by P.R.
      when /iPad/                       ; 'iPad'
      when /iPod/                       ; 'iPod'
      when /iPhone/                     ; 'iPhone'
      when /xbox.?one/                  ; 'Xbox One'
      when /xbox/                       ; 'Xbox'
      when /windows nt 10/i             ; 'Windows 10'
      when /windows nt 6\.[2-9]/i       ; 'Windows 8'
      when /windows nt 6\.1/i           ; 'Windows 7'
      when /windows nt 6\.0/i           ; 'Windows Vista'
      when /windows nt 5\.2/i           ; 'Windows 2003'
      when /windows nt 5\.1/i           ; 'Windows XP'
      when /windows nt 5\.0/i           ; 'Windows 2000'
      when /os x (\d+)[._]([\d\._]+)/i  ; "OS X #{$1}.#{$2}"
      when /os x/i                      ; "OS X"
      when /Darwin(\/(\S+))?/i          ; "Darwin #{$2}"
      when /(Nintendo\w*\s*\w*)/i       ; "#{$1}"
      when /ubuntu/i                    ; "Ubuntu"
      when /linux(\/(\S+))?/i           ; "Linux #{$2}"
      when /wii/i                       ; "Wii"
      when /playstation/i               ; "Playstation"
      when /Haiku\/(\S+)/i              ; "Haiku #{$1}"
      else                              ; "Unknown"
    end

    # TODO implement os_version and os_arch

    return self
  end

  # Reset all the fields of the user agent.
  def reset
    self.browser_name    = nil
    self.browser_version = nil
    self.os_name         = nil
    self.os_version      = nil
    self.os_arch         = nil
  end

end

