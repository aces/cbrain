
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

  def adjust_site
    cluster_name = self.cluster_name
    raise "ActiveRecord for DrmaaTask missing cluster_name ?!?" unless cluster_name
    self.class.send('adjust_site',cluster_name)
    self
  end

  def self.adjust_site(cluster_name)
    raise "DrmaaTask not supplied with cluster_name ?!?" unless cluster_name
    clustersite = CBRAIN_CLUSTERS::Clusters_resource_sites[cluster_name]
    raise "Cannot find site URI for cluster name #{cluster_name}" unless site
    return if clustersite == self.site.to_s
    self.site = clustersite
    self
  end

  def initialize(options = {})
    returning super(options) do |obj|
      obj.cluster_name = nil unless obj.attributes.has_key?('cluster_name')
    end
  end

  def save
    self.cluster_name = select_cluster unless self.cluster_name
    adjust_site
    super
  end

  def save!
    self.cluster_name = select_cluster unless self.cluster_name
    adjust_site
    super
  end

  def select_cluster
    cluster_list = CBRAIN_CLUSTERS::CBRAIN_cluster_list
    cluster_list.slice(rand(cluster_list.size))  # a random one
  end

end

