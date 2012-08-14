
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

###################################################################
# CBRAIN Kernel extensions
###################################################################
module Kernel

  private

  # Raises a CbrainNotice exception, with a default redirect to
  # the current controller's index action.
  def cb_notify(message = "Something may have gone awry.", options = {} )
    options[:status]       ||= :ok
    options[:shift_caller]   = 2
    raise CbrainNotice.new(message, options)
  end
  alias cb_notice cb_notify

  # Raises a CbrainError exception, with a default redirect to
  # the current controller's index action.
  def cb_error(message = "Some error occured.",  options = {} )
    options[:status]       ||= :bad_request
    options[:shift_caller]   = 2
    raise CbrainError.new(message, options)
  end

  # Debugging tools; this is a 'puts' where the string is colorized.
  def puts_red(message)
    puts "\e[31m#{message}\e[0m"
  end

  # Debugging tools; this is a 'puts' where the string is colorized.
  def puts_green(message)
    puts "\e[32m#{message}\e[0m"
  end

  # Debugging tools; this is a 'puts' where the string is colorized.
  def puts_blue(message)
    puts "\e[34m#{message}\e[0m"
  end

  # Debugging tools; this is a 'puts' where the string is colorized.
  def puts_yellow(message)
    puts "\e[33m#{message}\e[0m"
  end

  # Debugging tools; this is a 'puts' where the string is colorized.
  def puts_magenta(message)
    puts "\e[35m#{message}\e[0m"
  end

  # Debugging tools; this is a 'puts' where the string is colorized.
  def puts_cyan(message)
    puts "\e[36m#{message}\e[0m"
  end
  
  # This acts like 'puts' but also displays timing
  # statistics since the last time puts_timer was
  # invoked. If +color+ is set, the message will
  # be colorized using one of the 'puts_{color}'
  # methods. If reset is true, the timing information
  # will be reset to 0.
  def puts_timer(message, colour = nil, reset = false)
    @@__DEBUG_TIMER__ ||= nil
    if reset
      @@__DEBUG_TIMER__ = nil
    end
    if @@__DEBUG_TIMER__
      @@__DEBUG_TIMER__.timed_puts(message, colour)
    else
      @@__DEBUG_TIMER__ = DebugTimer.new
      method = "puts"
      if colour
        method = "puts_#{colour}"
      end
      send method, message
    end
  end

  # Run a given block with some environment variables
  # changed to what the +changed_env+ hash provides.
  # Use a value of nil in changed_env to delete environment
  # variables.
  # The environment is restored to its original state
  # when the block completes.
  def with_modified_env(changed_env={})
    varnames = changed_env.keys.inject({}) { |names,n| names[n] = nil; names } # we use the nil values later on
    saved    = ENV.select { |name,_| varnames.has_key?(name) }
    ENV.update(changed_env)
    yield
  ensure
    ENV.reject!           { |name,_| varnames.has_key?(name) }
    ENV.update(saved)
  end

  # Run a given block with ONLY the environment variables
  # set in the hash +new_env+.
  # The environment is restored to its original state
  # when the block completes.
  def with_only_env(new_env=(),&block)
    zapped = ENV.keys.inject({}) { |names,n| names[n] = nil ; names }
    zapped.merge! new_env
    with_modified_env(zapped, &block)
  end

end

