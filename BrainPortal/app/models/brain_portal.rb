
#
# CBRAIN Project
#
# Original author: Pierre Rioux
#
# $Id$
#


# This model represents a BrainPortal RAILS app.
class BrainPortal < RemoteResource

  Revision_info=CbrainFileRevision[__FILE__]
    
  def lock! #:nodoc:
    self.update_attributes!(:portal_locked => true)
  end
  
  def unlock! #:nodoc:
    self.update_attributes!(:portal_locked => false)
  end
  
  def license_agreements
    self.meta[:license_agreements] || []
  end
  
  def license_agreements=(agreements)
    agrs = agreements
    unless agrs.is_a? Array
      agrs = agrs.to_s.split(/[,\s]+/).map { |a| a.sub(/\.html$/, "").gsub(/[^\w-]+/, "") }.uniq
    end
    self.meta[:license_agreements] = agrs
  end

end
