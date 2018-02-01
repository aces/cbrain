
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

# Create a new logger for ActiveRecord operations
console_logger              = Logger.new(STDOUT)
console_logger.formatter    = Proc.new { |s,d,p,m| "#{m}\n" }
ApplicationRecord.logger    = console_logger
ActiveResource::Base.logger = console_logger

# Disable AR logging (actually, just sets logging level to ERROR).
# If a block is given, the effect only lasts for the duration
# of the block, and then logging is returned to whatever state
# it was originally. With no block given, it's permanent until
# do_log() is invoked.
def no_log(&block)
  set_log_level(Logger::ERROR,&block)
end

# Enable AR logging (actually, just sets logging level to DEBUG).
# If a block is given, the effect only lasts for the duration
# of the block, and then logging is returned to whatever state
# it was originally. With no block given, it's permanent until
# no_log() is invoked.
def do_log(&block)
  set_log_level(Logger::DEBUG,&block)
end

# Toggle log level for the two loggers
def set_log_level(level) #:nodoc:
  console_logger       = ApplicationRecord.logger
  previous_level       = console_logger.level
  console_logger.level = level
  return unless block_given?
  begin
    return yield
  ensure
    console_logger.level = previous_level
  end
end

(CbrainConsoleFeatures ||= []) << <<FEATURES
========================================================
Feature: Toggling ActiveRecord logging messages
========================================================
  (These things: "User Load (0.8ms) SELECT `users`...")
  Turn on or off permanently with: do_log ; no_log
  Note: these two methods can take a block and apply the
  log setting restriction while running it.
FEATURES

