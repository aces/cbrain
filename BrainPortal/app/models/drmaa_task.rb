
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

  # This sets the default resource address to an
  # invalid URL; it will be replaced as needed by the
  # URL of a real bourreau ActiveResource later on.
  self.site = "http://invalid:0000/"

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
  # the object's bourreau_id attribute. It's performed by
  # the class method of the same name, adjust_site(bourreau_id),
  # just below.
  def adjust_site
    bourreau_id = self.bourreau_id
    raise "ActiveRecord for DrmaaTask missing bourreau_id ?!?" unless bourreau_id
    self.class.adjust_site(bourreau_id)
    self
  end

  # This class method resets the class' "site" attribute
  # to point to the proper bourreau URI associated with
  # the bourreau_id given in argument.
  def self.adjust_site(bourreau_id)
    raise "DrmaaTask not supplied with bourreau ID ?!?" unless bourreau_id
    bourreau = Bourreau.find(bourreau_id)
    raise "Cannot find site URI for Bourreau ID #{bourreau_id}" unless bourreau
    clustersite = bourreau.site
    return self if clustersite == self.site.to_s # optimize if unchanged
    self.site = clustersite # class method call
    self
  end

  # A patch in the initialization process makes sure that
  # all new active record objects always have an attribute
  # called 'bourreau_id', even a nil one. This is necessary
  # so that just after initialization, we can call the instance
  # method .bourreau_id and get an answer instead of raising
  # an exception for method not found. This happens in .save
  # where an unset bourreau ID is replaced by a (randomly?)
  # chosen bourreau ID.
  def initialize(options = {})
    returning super(options) do |obj|
      obj.bourreau_id  = nil unless obj.attributes.has_key?('bourreau_id')
    end
  end

  # If a bourreau has not been specified, choose one.
  # Then, reconfigure the class' site to point to it properly.
  def save
    self.bourreau_id = select_bourreau unless self.bourreau_id
    adjust_site
    self.params ||= {}
    if self.params.respond_to? :[]
      self.params[:data_provider_id] = DrmaaTask.data_provider_id unless self.params[:data_provider_id]
    end    
    super
  end

  # If a bourreau has not been specified, choose one.
  # Then, reconfigure the class' site to point to it properly.
  def save!
    self.bourreau_id = select_bourreau unless self.bourreau_id
    adjust_site
    self.params ||= {}
    if self.params.respond_to? :[]
      self.params[:data_provider_id] = DrmaaTask.data_provider_id unless self.params[:data_provider_id]
    end
    super
  end

  # Choose a random Bourreau from the configured list
  # of legal bourreaux
  def select_bourreau
    unless DrmaaTask.prefered_bourreau_id.blank?
      DrmaaTask.prefered_bourreau_id
    else
      everyone_group_id = Group.find_by_name('everyone').id
      bourreau_list = Bourreau.find(:all, :conditions => { :group_id => everyone_group_id, online => true })
      bourreau_list.slice(rand(bourreau_list.size))  # a random one
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
  
  def self.prefered_bourreau_id
    @@prefered_bourreau_id ||= nil
  end
  
  def self.prefered_bourreau_id=(id)
    @@prefered_bourreau_id = id
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

  def bourreau
    Bourreau.find(self.bourreau_id)
  end

end

