
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
  self.site = CBRAIN::Clusters_resource_sites[CBRAIN::Cluster_list[0]]

  # This is an overidde of the ActiveResource method
  # used to instanciate objects received from the XML
  # stream; this method will use the attribute 'type',
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

  # This is an override of the ActiveResource method
  # used to instanciate objects received from the XML
  # stream; normally attributes that contain complex types
  # (like arrays and hashes) are recreated as sub-resources,
  # but for the "params" attribute we want the hash table
  # itself, so this routine provides this modification in
  # the behavior of the normal +load+ method.
  def load(attributes)
    raise ArgumentError, "expected an attributes Hash, got #{attributes.inspect}" unless attributes.is_a?(Hash)
    @prefix_options, attributes = split_options(attributes)
    attributes.each do |key, value|
      # Start of CBRAIN patch
      if key.to_s == "params"
        @attributes["params"] = value
        next
      end
      # End of CBRAIN patch
      @attributes[key.to_s] =
        case value
          when Array
            resource = find_or_create_resource_for_collection(key)
            value.map { |attrs| attrs.is_a?(String) ? attrs.dup : resource.new(attrs) }
          when Hash
            resource = find_or_create_resource_for(key)
            resource.new(value)
          else
            value.dup rescue value
        end
    end
    self
  end

  # This instance method resets the class' "site" attribute
  # to point to the proper bourreau URI associated with
  # the object's cluster_name attribute. It's performed by
  # the class method of the same name, adjust_site(cluster_name),
  # just below.
  def adjust_site
    cluster_name = self.cluster_name
    raise "ActiveRecord for DrmaaTask missing cluster_name ?!?" unless cluster_name
    self.class.adjust_site(cluster_name)
    self
  end

  # This class method resets the class' "site" attribute
  # to point to the proper bourreau URI associated with
  # the cluster_name given in argument.
  def self.adjust_site(cluster_name)
    raise "DrmaaTask not supplied with cluster_name ?!?" unless cluster_name
    clustersite = CBRAIN::Clusters_resource_sites[cluster_name]
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
    self.params ||= {}
    if self.params.respond_to? :[]
      self.params[:data_provider_id] = DrmaaTask.data_provider_id unless self.params[:data_provider_id]
    end    
    super
  end

  # If a cluster name has not been specified, choose one.
  # Then, reconfigure the class' site to point to it properly.
  def save!
    self.cluster_name = select_cluster unless self.cluster_name
    adjust_site
    if self.params.respond_to? :[]
      self.params[:data_provider_id] = DrmaaTask.data_provider_id unless self.params[:data_provider_id]
    end
    super
  end

  # Choose a random cluster name from the configured list
  # of legal cluster names.
  def select_cluster
    unless DrmaaTask.prefered_cluster.blank?
      DrmaaTask.prefered_cluster
    else
      cluster_list = CBRAIN::Cluster_list
      cluster_list.slice(rand(cluster_list.size))  # a random one
    end
  end
  
  #predicate indicating whether or not the given takes any command line arguments
  def self.has_args?
    false
  end
  
  def self.get_default_args(params = {}, saved_args = nil)
    {}
  end
  
  def self.launch(params = {})
    ""      #returns a string to be used in flash[:notice]
  end
  
  def self.save_options(params)
    {}      #create the hash of options to be saved
  end
  
  def self.prefered_cluster
    @@prefered_cluster ||= nil
  end
  
  def self.prefered_cluster=(cluster)
    @@prefered_cluster = cluster
  end
  
  def self.data_provider_id
    @@data_provider_id ||= nil
  end
  
  def self.data_provider_id=(provider)
    if provider.is_a? DataProvider
      @@data_provider_id = provider.id
    else
      @@data_provider_id = provider
    end
  end
end

