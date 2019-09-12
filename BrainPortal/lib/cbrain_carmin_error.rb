
#
# CBRAIN Project
#
# Copyright (C) 2008-2019
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

# Use this exception class for notification
# of serious errors within CBRAIN code.
class CbrainCarminError < CbrainError

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  attr_accessor :error_code

  def initialize(message = "CARMIN API error", options = {})
    ex = super
    ex.error_code   = options[:error_code] if options[:error_code].present?
    ex.error_code ||= 1
    ex
  end

end

