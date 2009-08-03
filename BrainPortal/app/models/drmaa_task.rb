
#
# CBRAIN Project
#
# DrmaaTask models as ActiveResource
#
# Original author: Pierre Rioux
#
# $Id$
#


#Abstract model representing a job request made to an remote execution server (Bourreau) on a cluster.
#
#<b>DrmaaTask should not be instantiated directly.</b> Instead, subclasses of DrmaaTask should be created to 
#represent requests for specific processing tasks. 
#These are *ActiveResource* models, meaning they do not access the database directly. Instead,
#they communicate with the execution server running on the remote cluster through HTTP.
#
#
#= Creating a DrmaaTask subclass
#Subclasses of DrmaaTask will have to override the following *class* methods to function properly:
#[<b>has_args?</b>] Does the processing task represented require command line arguments (and thus
#                   a view for inputing them)?
#[*get_default_args*] (only required if <tt>has_args?</tt> returns true). Returns a hash of default
#                     arguments (if desired) for setting up the argument input view.
#[*launch*] Setup and launch the request to the remote cluster.
#[*save_options*] Return a hash of the options to be saved to a user's preferences if they 
#                 request to do so.
#
#A generator script has been written to simplify the creation of DrmaaTask subclasses. To
#use it, simply go to the BrainPortal application's base directory and run:
#  script/generate cluster_task <your_task_name>
#This will create a template for your task as well as a view for inputing arguments to the task.
#To create a task that doesn't require arguments, simply run:
#  script/generate cluster_task <your_task_name> --no-view
#Instructions in the files themselves will indicate how to integrate your task into the system.
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
  def self.instantiate_record(record, prefix_options = {}) #:nodoc:
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
  def load(attributes) #:nodoc:
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
  # the class method of the same name.
  def adjust_site
    bourreau_id = self.bourreau_id
    raise "ActiveRecord for DrmaaTask missing bourreau_id ?!?" unless bourreau_id
    self.class.adjust_site(bourreau_id)
    self
  end

  # This class method resets the class' "site" attribute
  # to point to the proper Bourreau URI associated with
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
  def initialize(options = {}) #:nodoc:
    returning super(options) do |obj|
      obj.bourreau_id  = nil unless obj.attributes.has_key?('bourreau_id')
    end
  end

  # If a bourreau has not been specified, choose one.
  # Then, reconfigure the class' site to point to it properly.
  def save #:nodoc:
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
  def save! #:nodoc:
    self.bourreau_id = select_bourreau unless self.bourreau_id
    adjust_site
    self.params ||= {}
    if self.params.respond_to? :[]
      self.params[:data_provider_id] = DrmaaTask.data_provider_id unless self.params[:data_provider_id]
    end
    super
  end

  #Choose a random Bourreau from the configured list
  #of legal bourreaux.
  def select_bourreau
    unless DrmaaTask.prefered_bourreau_id.blank?
      DrmaaTask.prefered_bourreau_id
    else
      everyone_group_id = Group.find_by_name('everyone').id
      bourreau_list = Bourreau.find(:all, :conditions => { :group_id => everyone_group_id, :online => true })
      bourreau_list.slice(rand(bourreau_list.size))  # a random one
    end
  end
  
  #This method should indicate whether or not the represented task requires 
  #arguments in order to run. If so the tasks/new view will be rendered
  #before the job is sent to the cluster.
  def self.has_args?
    false
  end
  
  #This method should return a hash containing the default arguments for
  #for the task to be executed. These can be used to set up the tasks/new form.
  #The saved_args argument is the hash from the user preferences for 
  #the DrmaaTask subclass (i.e. a given user's prefered arguments, 
  #if he/she chooses to save them). It is the hash created by the 
  #save_options class method.
  #
  #If an exception is raised here it will cause a redirect to the 
  #userfiles index page where the exception message will be displayed.
  def self.get_default_args(params = {}, saved_args = nil)
    {}
  end
  
  #This method actually launches the requested job on the cluster, 
  #and returns the flash message to be displayed to the user.
  #Default behaviour is to launch the job to the user's prefered cluster,
  #or if the latter is not set, to choose an available cluster at random.
  #You can select a specific cluster to launch to by setting the 
  #bourreau_id attribute on the DrmaaTask subclass object (task.bourreau_id) 
  #explicitly.
  #
  #If an exception is raised here, it will cause a redirect to one of the 
  #following pages:
  #[<b>The argument input page (tasks/new)</b>] if the task has an argument input page 
  #                                             (i.e. has_args? returns true).
  #[<b>The Userfile index (userfiles/index)</b>] if the task has no argument input page 
  #                                              (i.e. has_args? returns false).
  #The exception message will be displayed to the user as 
  #a flash message after the redirect.
  #
  #<b>Example:</b>
  #         def self.launch(params)
  #           flash = "Flash[:notice] message."
  #           file_ids = params[:file_ids]
  #           
  #           file_ids.each do |id|
  #             userfile = Userfile.find(id, :include  => :user)
  #             task = DrmaaYourClass.new
  #             task.user_id = userfile.user.id
  #             task.params = { :mincfile_id => id }
  #             task.save
  #             
  #             flash += "Started DrmaaYourClass on file '#{userfile.name}'.\n"
  #           end
  #           flash   
  #         end     
  def self.launch(params = {})
    ""      #returns a string to be used in flash[:notice]
  end
  
  #This method creates a hash of the options to be saved in the user's
  #preferences (see UserPreference). It will be stored in:  
  # <user_preference>.other_options["DrmaaYourClass_options"]
  #This hash is automatically passed to the get_default_args class method
  #for each task creation request.
  def self.save_options(params)
    {}      #create the hash of options to be saved
  end
  
  #Retreive the id of the preferred Bourreau for this task.
  def self.prefered_bourreau_id
    @@prefered_bourreau_id ||= nil
  end
  
  #Set the id of the preferred Bourreau for this task.
  def self.prefered_bourreau_id=(id)
    @@prefered_bourreau_id = id
  end
  
  #Retreive the id of the provider to save output to 
  #when the task is complete.
  def self.data_provider_id
    @@data_provider_id ||= nil
  end
  
  #Set the id of the provider to save output to 
  #when the task is complete.
  def self.data_provider_id=(provider)
    if provider.is_a? DataProvider
      @@data_provider_id = provider.id
    else
      @@data_provider_id = provider
    end
  end

  #Return the Bourreau object associated with this task.
  def bourreau
    @bourreau ||= Bourreau.find(self.bourreau_id)
  end

  # Returns an ID string containing both the bourreau_id +b+
  # and the task ID +t+ in format "b/t"
  def bid_tid
    "#{self.bourreau_id || '?'}/#{self.id || '?'}"
  end

  # Returns an ID string containing both the bourreau_name +b+
  # and the task ID +t+ in format "b/t"
  def bname_tid
    "#{self.bourreau.name || '?'}/#{self.id || '?'}"
  end

end

