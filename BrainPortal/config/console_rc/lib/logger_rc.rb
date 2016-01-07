
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
ActiveRecord::Base.logger   = console_logger
ActiveResource::Base.logger = console_logger

# Disable AR logging (actually, just sets logging level to ERROR).
# If a block is given, the effect only lasts for the duration
# of the block, and then logging is returned to whatever state
# it was originally. With no block given, it's permanent until
# do_log() is invoked.
def no_log(&block)
  set_log_level(Logger::ERROR,&block) rescue nil
end

# Enable AR logging (actually, just sets logging level to DEBUG).
# If a block is given, the effect only lasts for the duration
# of the block, and then logging is returned to whatever state
# it was originally. With no block given, it's permanent until
# no_log() is invoked.
def do_log(&block)
  set_log_level(Logger::DEBUG,&block) rescue nil
end

# Toggle log level for the two loggers
def set_log_level(level) #:nodoc:
  l1 = ActiveRecord::Base.logger.level   rescue nil
  l2 = ActiveResource::Base.logger.level rescue nil
  ActiveRecord::Base.logger.level   = level rescue true
  ActiveResource::Base.logger.level = level rescue true
  if block_given?
    begin
      return yield
    ensure
      ActiveRecord::Base.logger.level   = l1 if l1
      ActiveResource::Base.logger.level = l2 if l2
    end
  end
end

