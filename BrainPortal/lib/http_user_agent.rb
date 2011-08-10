
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
      next unless comp =~ /^(\S+)\/(\S+)$/
      name  = Regexp.last_match[1]
      value = Regexp.last_match[2]
      next if keyvals.has_key?(name.downcase) # first match has priority
      keyvals[name.downcase] = value
      lastname = name
    end

    # Identify the browser
    priority_list = [ 'Konqueror', 'Chrome', 'Safari', 'Opera', 'Firefox', 'MSIE', "CbrainPerlAPI", lastname ]
    priority_list.each do |name|
      lcname = name.downcase
      next unless keyvals.has_key?(lcname)
      self.browser_name    = name
      self.browser_version = keyvals[lcname]
      break
    end

    # Identify the OS and architecture
    self.os_name = case adj_ua # case statement mostly from D. Meyer's code
      when /iPad/                       ; 'iPad'
      when /iPod/                       ; 'iPod'
      when /iPhone/                     ; 'iPhone'
      when /windows nt 6\.0/i           ; 'Windows Vista'
      when /windows nt 6\.\d+/i         ; 'Windows 7'
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
      else                              ; "Unknown"
    end

    # TODO implement os_version and os_arch

    return self
  end

  def reset
    self.browser_name    = nil
    self.browser_version = nil
    self.os_name         = nil
    self.os_version      = nil
    self.os_arch         = nil
  end

end
