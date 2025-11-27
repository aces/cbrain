
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
      helper_method :cbrain_request_remote_ip, :ban_ip, :ban_ip_on_spurious_params
      extend ClassMethods
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

  # A controller method can instantaneously add the
  # current client to the list of banned IP addresses;
  # this method also sets the return code to 401, as
  # will all future requests from that client. See
  # also the ApplicationController method +check_for_banned_ip+
  def ban_ip(message)
    req_ip = cbrain_request_remote_ip
    Rails.logger.info("Banning IP #{req_ip}: #{message}")
    if req_ip != '127.0.0.1' # need to check for IPv6 too eventually
      BannedIps.ban_ip(req_ip)
      system("#{Rails.root}/vendor/cbrain/bin/ban_ip", req_ip.to_s)
    end
    head :unauthorized
    false
  end

  module ClassMethods

    # Returns the list registered allowed params
    # for some actions filtered by the controller helper
    # method spurious_params_ban_ip
    def allowed_params_by_action #:nodoc:
      @allowed_params_by_action || {}
    end

    # This is a helper method for controllers.
    # Register for an action the list of param keys
    # that are allowed; if any extra keys are found in
    # a request, the IP address is banned using ban_ip.
    # For example:
    #
    #   (In SessionsController)
    #   spurious_params_ban_ip :create => [ :login, :password ]
    #
    # You can provide first a plain list of actions names,
    #  which imply "actionname" => [], followed by a hash with the
    # action names as keys and the allowed params as values:
    #
    #   spurious_params_ban_ip :new, :destroy, :show,
    #      :create  => [ :login, :pw ],
    #      :inspect => [ :verbose ]
    #
    # is the same as
    #
    #   spurious_params_ban_ip :new => [], :destroy => [], :show => [],
    #      :create  => [ :login, :pw ],
    #      :inspect => [ :verbose ]
    #
    def spurious_params_ban_ip(*action_params)
      @allowed_params_by_action ||= {}
      action_params.each do |item|
        if item.is_a?(Hash)
          item.each { |action,ok_params| @allowed_params_by_action[action.to_s] = Array(ok_params) }
        else
          @allowed_params_by_action[item.to_s] = []
        end
      end
      before_action :ban_ip_on_spurious_params, :only => @allowed_params_by_action.keys
    end

  end

  STANDARD_PARAMS_THAT_DO_NOT_TRIGGER_BANS = %w( id utf8 commit authenticity_token controller action cbrain_api_token format )
  MINIMUM_NUMBER_OF_SPURIOUS_PARAMS = 3 # we need at least that many spurious params to trigger a ban

  # Called as a before_action method for actions that
  # need to have a specific list of params.
  def ban_ip_on_spurious_params #:nodoc:

    # Does the current action have a list of allowed params?
    ok_params     = self.class.allowed_params_by_action[params[:action].to_s]
    return true if ok_params.nil? # no list for this action, so make no further verifs

    # Find out the ones we don't expect
    extended_keys = ok_params.map(&:to_s) + STANDARD_PARAMS_THAT_DO_NOT_TRIGGER_BANS
    spurious_keys = params.keys.map(&:to_s) - extended_keys
    return true if spurious_keys.empty? # everything is good

    # Prepare message
    num_spurious = spurious_keys.size
    first_four   = spurious_keys[0..3].join(", ")
    first_four  += " (... #{num_spurious} keys in total)" if num_spurious > 4

    # Report
    if num_spurious < MINIMUM_NUMBER_OF_SPURIOUS_PARAMS
      Rails.logger.error "Found some spurious parameters: #{first_four}"
      return true # don't ban
    end

    # Ban
    ban_ip("Spurious parameters detected: #{first_four}") # will return status unauthorized too
  end

end

