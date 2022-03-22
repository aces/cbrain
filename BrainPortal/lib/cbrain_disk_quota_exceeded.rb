
#
# CBRAIN Project
#
# Copyright (C) 2008-2022
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
# of disk quota exceeded.
class CbrainDiskQuotaExceeded < CbrainError

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def initialize(user_id, data_provider_id)
    message =
      "Disk Quota Exceeded" +
      " for user '#{User.find(user_id).login}'" +
      " on data provider '#{DataProvider.find(data_provider_id).name}'"
    super(message)

    self
  end

end

