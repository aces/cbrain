
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
  
  def self.current_portal
    find(CBRAIN::SelfRemoteResourceId)
  end
  
  def lock!
    self.update_attributes!(:portal_locked => true)
  end
  
  def unlock!
    self.update_attributes!(:portal_locked => false)
  end
end
