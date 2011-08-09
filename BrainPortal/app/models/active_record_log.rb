
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

end

