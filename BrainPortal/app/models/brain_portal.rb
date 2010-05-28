
#
# CBRAIN Project
#
# Original author: Pierre Rioux
#
# $Id$
#


# This model represents a BrainPortal RAILS app.
class BrainPortal < RemoteResource

  Revision_info="$Id$"
  
  def lock! #:nodoc:
    self.update_attributes!(:portal_locked => true)
  end
  
  def unlock! #:nodoc:
    self.update_attributes!(:portal_locked => false)
  end

end
