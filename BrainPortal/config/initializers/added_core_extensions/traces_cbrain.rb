
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

# -------------------------------------------------------------------------
# Traces of system() and IO.popen enabled with CBRAIN_DEBUG_TRACES
# -------------------------------------------------------------------------

if ENV['CBRAIN_DEBUG_TRACES'].present? && ! defined?($CBRAIN_DEBUG_OVERRIDE)

  $CBRAIN_DEBUG_OVERRIDE=true # we use this ugly global in the rare case where this file is sourced twice

  puts_red "CBRAIN: Enabling debug traces of some system functions."

  #
  module Kernel

    puts_red "CBRAIN: Kernel.system() patched to track arguments and stack trace."

    alias :cbrain_orig_system :system #:nodoc:

    def system(*args) #:nodoc:
      puts_green "Kernel.system(): #{args.to_s}"
      prefix = Rails.root.parent.to_s + "/"
      mytraces = caller.select { |line| line[prefix] && line[prefix]="" }
      mytraces[0,8].each { |line| puts_yellow line }
      cbrain_orig_system(*args)
    end
  end

  class IO #:nodoc:
    class << self

      puts_red "CBRAIN: IO.popen() patched to track arguments and stack trace."

      alias :cbrain_orig_popen :popen #:nodoc:

      def popen(*args,&block) #:nodoc:
        puts_green "IO.popen: #{args.to_s}"
        prefix = Rails.root.parent.to_s + "/"
        mytraces = caller.select { |line| line[prefix] && line[prefix]="" }
        mytraces[0,8].each { |line| puts_yellow line }
        cbrain_orig_popen(*args,&block)
      end
    end
  end

end

# -------------------------------------------------------------------------
# Traces of SQL queries enabled with CBRAIN_DEBUG_SQL_SOURCE_LINES=numlines
# -------------------------------------------------------------------------

if ENV["CBRAIN_DEBUG_SQL_SOURCE_LINES"].present? && ENV["CBRAIN_DEBUG_SQL_SOURCE_LINES"] =~ /\A[1-9]\d*\z/

# Adapted from
# http://www.jkfill.com/2015/02/14/log-which-line-caused-a-query/

module LogQuerySource

  CBRAIN_SHOW_LINES = ENV["CBRAIN_DEBUG_SQL_SOURCE_LINES"].to_i

  puts_red "CBRAIN: Enabling debug traces of ActiveRecord::Relation SQL calls (#{CBRAIN_SHOW_LINES} lines)"

  def debug(*args, &block)
    return unless super

    backtrace = Rails.backtrace_cleaner.clean caller

    relevant_caller_lines = backtrace[0..LogQuerySource::CBRAIN_SHOW_LINES]
    relevant_caller_lines.each do |line|
      line.sub!(/(.*?):(\d+):/,"\e[0;33m\\1\e[0m : \\2 :")
      logger.debug("  ->  #{line}")
    end

  end
end

ActiveRecord::LogSubscriber.send :prepend, LogQuerySource

end
