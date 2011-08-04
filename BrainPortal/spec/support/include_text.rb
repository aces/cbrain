module RSpec::Rails
  module Matchers
    RSpec::Matchers.define :include_text do |text|
      match do |response_or_text|
        @content = response_or_text.respond_to?(:body) ? response_or_text.body : response_or_text
        if text.is_a?(Regexp)
          @content =~ text
        else
          @content.include?(text)
        end
      end

      failure_message_for_should do |text|
        "expected '#{@content}' to contain '#{text}'"
      end

      failure_message_for_should_not do |text|
        "expected #{@content} to not contain '#{text}'"
      end
    end
  end
end


