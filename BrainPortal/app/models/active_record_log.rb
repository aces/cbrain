
#
# CBRAIN Project
#
# General Active Record Logging Mechanism
# See the module ActRecLog for more information.
#
# Original author: Pierre Rioux
#
# $Id$
#

class ActiveRecordLog < ActiveRecord::Base

  Revision_info=CbrainFileRevision[__FILE__]

  force_text_attribute_encoding 'UTF-8', :log

  def active_record_object #:nodoc:
    ar_id = self.ar_id
    klass = self.ar_class.constantize rescue nil
    return nil unless klass && ar_id && klass < ActiveRecord::Base
    klass.find_by_id(ar_id)
  end

end

