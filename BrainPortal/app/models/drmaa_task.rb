
#
# CBRAIN Project
#
# DrmaaTask models as ActiveResource
#
# Original author: Pierre Rioux
#
# $Id$
#

class DrmaaTask < ActiveResource::Base

  Revision_info="$Id$"

  # This sets the default resource address to the first cluster
  # listed in the clusters.rb initializer file; it probably
  # will be overriden in each subclasses, often several times
  # per sessions as we fetch our ActiveResource objects from
  # multiple Bourreau servers.
  self.site = CBRAIN_CLUSTERS::Clusters_resource_sites[CBRAIN_CLUSTERS::CBRAIN_cluster_list[0]]

  # This is an overidde of the ActiveResource method
  # used to instanciate objects received from the XML
  # stream; this methods will use the attribute 'type',
  # if available, to select the class of the object being
  # reconstructed.
  def self.instantiate_record(record, prefix_options = {})
    if record.empty? || ! record.has_key?("type")
      obj = super(record,prefix_options)
      obj.adjust_site
    else
      subtype = record.delete("type")
      subclass = Class.const_get(subtype)
      returning subclass.new(record) do |resource|
        resource.prefix_options = prefix_options
        resource.adjust_site
      end
    end
  end

  # This instance method resets the class' "site" attribute
  # to point to the proper bourreau URI associated with
  # the object's cluster_name attribute. It's performed by
  # the class method of the same name, adjust_site(cluster_name),
  # just below.
  def adjust_site
    cluster_name = self.cluster_name
    raise "ActiveRecord for DrmaaTask missing cluster_name ?!?" unless cluster_name
    self.class.send('adjust_site',cluster_name)
    self
  end

  # This class method resets the class' "site" attribute
  # to point to the proper bourreau URI associated with
  # the cluster_name given in argument.
  def self.adjust_site(cluster_name)
    raise "DrmaaTask not supplied with cluster_name ?!?" unless cluster_name
    clustersite = CBRAIN_CLUSTERS::Clusters_resource_sites[cluster_name]
    raise "Cannot find site URI for cluster name #{cluster_name}" unless site
    return self if clustersite == self.site.to_s # optimize if unchanged
    self.site = clustersite
    self
  end

  # A patch in the initialization process makes sure that
  # all new active record objects always have an attribute
  # called 'cluster_name', even a nil one. This is necessary
  # so that just after initialization, we can call the instance
  # method .cluster_name and get an answer instead of raising
  # an exception for method not found. This happens in .save
  # where an unset cluster name is replaced by a (randomly?)
  # chosen cluster name.
  def initialize(options = {})
    returning super(options) do |obj|
      obj.cluster_name = nil unless obj.attributes.has_key?('cluster_name')
    end
  end

  # If a cluster name has not been specified, choose one.
  # Then, reconfigure the class' site to point to it properly.
  def save
    self.cluster_name = select_cluster unless self.cluster_name
    adjust_site
    super
  end

  # If a cluster name has not been specified, choose one.
  # Then, reconfigure the class' site to point to it properly.
  def save!
    self.cluster_name = select_cluster unless self.cluster_name
    adjust_site
    super
  end

  # Choose a random cluster name from the configured list
  # of legal cluster names.
  def select_cluster
    cluster_list = CBRAIN_CLUSTERS::CBRAIN_cluster_list
    cluster_list.slice(rand(cluster_list.size))  # a random one
  end

end

