
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

#
# This class is used to maintain the metadata associated with
# any other ActiveRecord object on the system. Most of the
# API for setting and getting values from the store is
# explained in the module ActRecMetaData, and in its class
# ActRecMetaData::MetaDataHandler .
#
# == The MetaData API for ActiveRecords
#
# See ActRecMetaData::MetaDataHandler , which provides a nice
# API to access the metadata store.
#
class MetaDataStore < ActiveRecord::Base

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  self.table_name = "meta_data_store" # singular

  serialize_as_indifferent_hash :meta_value # not necessarily a hash, actually

  validates_presence_of   :meta_key
  validates_uniqueness_of :meta_key, :scope => [ :ar_id, :ar_table_name ]

  # attr_accessible :ar_id, :ar_table_name, :meta_key, :meta_value

  def active_record_object #:nodoc:
    ar_id = self.ar_id
    klass = self.ar_table_name.classify.constantize rescue nil
    return nil unless klass && ar_id && klass < ActiveRecord::Base
    klass.find_by_id(ar_id)
  end

end

