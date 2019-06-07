
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

# Helpers for the HTTP requests
module RequestHelpers

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.included(includer) #:nodoc:
    includer.class_eval do
      helper_method :cbrain_request_remote_ip
    end
  end

  # Returns the current IP of the HTTP client.
  # Normally this would be just like Rails'
  # request.remote_ip, but that sometimes fail
  # and it returns 'localhost' so we go back to
  # processing the ENV variables ourselves... :-(
  def cbrain_request_remote_ip
    return @_remote_ip if @_remote_ip

    # Rails attempts
    @_remote_ip = request.remote_ip # from Rails
    return @_remote_ip if @_remote_ip.present? && @_remote_ip != '127.0.0.1'

    # Custom fallback code
    reqenv      = request.env || {}
    env_ip      = reqenv['HTTP_X_FORWARDED_FOR'] || reqenv['HTTP_X_REAL_IP'] || reqenv['REMOTE_ADDR']
    @_remote_ip = Regexp.last_match[1] if ((env_ip || "") =~ /(\d+\.\d+\.\d+\.\d+)/) # sometimes we get several IPs with commas
    @_remote_ip
  end

end

