
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

# This model stores the logs for any other
# ActiveRecord model objects. See the ActRecLog module
# for more information about the API.
class ActiveRecordLog < ActiveRecord::Base

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  attr_accessible :ar_id, :ar_table_name, :log

  def active_record_object #:nodoc:
    ar_id = self.ar_id
    klass = self.ar_table_name.classify.constantize rescue nil
    return nil unless klass && ar_id && klass < ActiveRecord::Base
    klass.find_by_id(ar_id)
  end

end

