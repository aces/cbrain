
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

class DebugTimer #:nodoc:

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Print a start message and restart the class-level timer.
  def self.start(message = "Timer starting at: #{Time.now}")
    puts message
    puts self.timer.reset
  end

  # Restart the class-level timer.
  def self.reset
    self.timer.reset
  end

  # Print using the class-level timer.
  def self.timed_puts(*args)
    self.timer.timed_puts(*args)
  end

  def initialize #:nodoc:
    @base_time      = Time.now
    @last_timepoint = @base_time
  end

  # Reset the timer.
  def reset
    @base_time      = Time.now
    @last_timepoint = @base_time
  end

  # Print a message, adding current timing statistics.
  def timed_puts(message, colour)
    method = "puts"
    if colour
      method = "puts_#{colour}"
    end
    send method, prepare_string(message)
  end

  # Added timing information to a string.
  def prepare_string(message)
    current_time = Time.now
    cumul_time = current_time - @base_time
    dif_time = current_time - @last_timepoint
    message += sprintf(": diff=%10.6fs / cumul=%10.6fs", dif_time, cumul_time)

    @last_timepoint = current_time
    message
  end

  private

  def self.timer #:nodoc:
    @@timer ||= self.new
  end
end

