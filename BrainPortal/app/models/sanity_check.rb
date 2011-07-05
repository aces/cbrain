
#
# CBRAIN Project
#
# SanityCheck model
#
# Original author: Nicolas Kassis
#
# $Id$
#

class SanityCheck < ActiveRecord::Base

  Revision_info=CbrainFileRevision[__FILE__]

  validates_presence_of :revision_info

end

