module ApiHelpers
  
  def self.included(includer)
    includer.class_eval do
      before_filter :api_validity_check
      extend ClassMethods
    end
  end
  
  #Before filter that checks that blocks certain actions
  #from the API
  def api_validity_check
    if request.format && request.format.to_sym == :xml
      valid_actions = self.class.api_actions || []
      current_action = params[:action].to_sym

      unless valid_actions.include? current_action
        render :xml => {:error  => "Action '#{current_action}' not available to API. Available actions are #{valid_actions.inspect}"}, :status  => :bad_request 
      end
    end
  end
  
  module ClassMethods
    #Directive to be used in controllers to make
    #actions available to the API
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