
#
# CBRAIN Project
#
# General Active Record Meta Data Store Mechanism
# See the module ActRecMetaData for more information.
#
# Original author: Pierre Rioux
#
# $Id$
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

  Revision_info="$Id$"

  self.table_name = "meta_data_store" # singular

  serialize :meta_value

  validates_presence_of   :meta_key
  validates_uniqueness_of :meta_key, :scope => [ :ar_id, :ar_class ]

end

