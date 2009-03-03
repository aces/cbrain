
#
# CBRAIN Project
#
# Cluster names and site configurations
#
# Original author: Pierre Rioux
#
# $Id$
#

require 'socket'

class CBRAIN_CLUSTERS

  public

  Revision_info="$Id$"

  # This is used by BrainPortal as the list of available clusters.
  # The defaults/prefered cluster is the first one
  CBRAIN_cluster_list = [ "unf-montreal" ]
  
  # This hash maps short names of clusters to the Bourreau resource URI
  # running on the clusters' frontends
  Clusters_resource_sites = { # keys are case-sensitive
      "Montague"  => "http://montague.bic.mni.mcgill.ca:3050/",
      "Huia"      => "http://huia.bic.mni.mcgill.ca:3050/",
      "Clumeq1"   => "http://localhost:3090/",
      "Krylov"    => "http://krylov.clumeq.mcgill.ca:3050/", # does not work, need tunneling, see "Clumeq1" tunneled on 3090
      "Localhost" => "http://localhost:3050/",
      "unf-montreal" => "http://morpheus.criugm.qc.ca:3050/"
  }

  # Set my OWN cluster name if I'm Bourreau
  if RAILS_ROOT.match(/\/Bourreau$/)
    hostname = Socket.gethostname
    case hostname
      when "huia.bic.mni.mcgill.ca"
        BOURREAU_CLUSTER_NAME = "Huia"   # case sensitive
      when /montague/
        BOURREAU_CLUSTER_NAME = "Montague"   # case sensitive
      when /morpheus/
        BOURREAU_CLUSTER_NAME = "unf-montreal"   # case sensitive; through tunneling
      when /krylov/
        BOURREAU_CLUSTER_NAME = "Clumeq1"   # case sensitive; through tunneling
    else
      raise "Configuration error: unsupported Bourreau hostname '#{hostname}'."
    end
  else
    BOURREAU_CLUSTER_NAME = nil    # on BrainPortal, we don't need this
  end

end

