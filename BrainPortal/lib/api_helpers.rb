
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

#Helpers for the CBRAIN web service API.
module ApiHelpers

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.included(includer) #:nodoc:
    includer.class_eval do
      before_action :api_validity_check
      extend ClassMethods
    end
  end

  # Returns true if the current request is an API request (JSON or XML)
  def api_request?
    #puts_red "CAT=#{@cbrain_api_token} #{params[:controller]} #{params[:action]}"
    #if ! @cbrain_api_token
    #  puts_yellow (Rails.backtrace_cleaner.clean caller).join("\n")
    #  puts_yellow "-------"
    #end
    return true if @cbrain_api_token
    return true if request.format.json?
    return true if request.format.xml?
    false
  end

  # Before filter that blocks certain actions from the API
  def api_validity_check
    return unless api_request?

    valid_actions  = self.class.api_actions || []
    current_action = params[:action].to_sym
    return if valid_actions.include? current_action

    error_obj = { :error => "Action '#{current_action}' not available to API. Available actions are #{valid_actions.inspect}" }
    respond_to do |format|
      format.xml  { render :xml  => error_obj, :status => :bad_request }
      format.json { render :json => error_obj, :status => :bad_request }
    end
  end

  module ClassMethods
    # Directive to be used in controllers to make
    # actions available to the API
    def api_available(actions = :all)
      @api_action_code = actions
    end

    def api_actions #:nodoc:
      unless @api_actions
        @api_actions ||= []
        actions = @api_action_code || :none
        case actions
        when :all
          @api_actions = self.instance_methods(false).map(&:to_sym)
        when :none
          @api_actions = []
        when Symbol
          @api_actions = [actions]
        when Array
          @api_actions = actions.map(&:to_sym)
        when Hash
          if actions[:only]
            only_available = actions[:only]
            only_available = [only_available] unless only_available.is_a?(Array)
            only_available.map!(&:to_sym)
            @api_actions = only_available
          elsif actions[:except]
            unavailable = actions[:except]
            unavailable = [unavailable] unless unavailable.is_a?(Array)
            unavailable.map!(&:to_sym)
            @api_actions = self.instance_methods(false).map(&:to_sym) - unavailable
          end
        else
          if actions.respond_to?(:to_sym)
            @api_actions << actions.to_sym
          else
            cb_error "Invalid action definition: #{actions}."
          end
        end
      end

      @api_actions
    end
  end
end

