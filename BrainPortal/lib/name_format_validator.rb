
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

class NameFormatValidator < ActiveModel::EachValidator #:nodoc:

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Iterator that validates name.
  def validate_each(object, attribute, value) #:nodoc:
    unless value.blank? || value =~ /\A[a-zA-Z0-9][ \w\~\!\@\#\%\^\*\-\+\=\:\;\,\.\?]*\z/
      object.errors[attribute] << (options[:message] || "contains invalid characters")
    end
  end

end

