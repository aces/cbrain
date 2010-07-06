
#
# CBRAIN Project
#
# CBRAIN extensions for storing metadata information to ANY
# object in the DB, as long as they have an 'id' field.
# Note that if the object being annotate is an ActiveRecord,
# then the callback after_destroy() will clean up all
# the metadata objects too. See the module ActRecMetaData
# for more information.
#
# Original author: Pierre Rioux
#
# $Id$
#

#
# = CBRAIN Metadata API
#
# This module is included in the base class ActiveRecord::Base
# and provides a simple interface to a metadata store. It
# allows a program to store arbitrary (key,value) pairs with
# any ActiveRecord object on the system.
#
# The basic access mechanism is through the meta() instance method
# added to the ActiveRecord::Base class. This returns an instance
# of a special handler object of type ActRecMetaData::MetaDataHandler that
# provides the interface to set and get metadata values for the original
# ActiveRecord object.
#
# == The MetaData API for ActiveRecords (see ActRecMetaData::MetaDataHandler)
#
# Storing metadata:
#
#   act_rec_object.meta[:author] = "Jane Austen"
#   act_rec_object.meta.attributes = { :year => 1797, :month => "Jan" }
#
# Getting metadata:
#
#   puts      act_rec_object.meta[:author]
#   list    = act_rec_object.meta.keys # all defined keys
#   as_hash = act_rec_object.meta.attributes
#
# Deleting metadata:
#
#   act_rec_object.meta.delete(:author)
#
# Getting a list of ActiveRecord objects with particular metadata:
#
#   objlist = SomeARclass.find_all_by_meta_data(:author, "Austen", :conditions => { :user_id => 3 })
#   # objlist will be an array of objects of type SomeARclass or subclasses of it
#
# == The 'meta_data_store' Table (see MetaDataStore)
#
# This table is a normal ActiveRecord table where all the meta
# data for all other ActiveRecord objects are stored, using the
# MetaDataStore model. It is normally NOT accessed by programs,
# as the API above is sufficient for most normal operations.
#
module ActRecMetaData

  Revision_info = "$Id$"

  # Check that the the class this module is being included into is a valid one.
  def self.included(includer)
    unless includer <= ActiveRecord::Base
      raise "#{includer} is not an ActiveRecord model. The ResourceAccess module cannot be used with it."
    end

    includer.class_eval do
      extend ClassMethods
    end
  end

  #
  # = MetaData Handler Class
  #
  # This class provides the method used to get and set metadata
  # on any ActiveRecord object. The class is used to provide
  # a handler for the object's metadata; this handler is obtained
  # by calling the meta() method on any instance of an ActiveRecord:
  #
  #   myobj = Userfile.find(23)
  #   myobj.meta     # returns the handler, which is not useful by itself.
  #
  # Given the handler, we can now get and set metadata by calling methods
  # on it:
  #
  #   myobj.meta[:author] = "prioux"
  #
  # For the rest of the API, see the documentation in module ActRecMetaData.
  class MetaDataHandler

    attr_accessor :md_cache, :ar_class, :ar_id

    def initialize(ar_id, ar_class) #:nodoc:
      self.ar_class = ar_class.to_s
      self.ar_id    = ar_id
      reload_cache
    end



    ###################################################################
    # Official MetaData API
    ###################################################################

    # Returns an array of all the keys defined
    # in the metadata store for the current
    # ActiveRecord object.
    def keys
      self.md_cache.keys
    end

    # Returns a hash table containing all the metadata
    # associated with the current ActiveRecord object.
    # Note that modifying this hash table has NO effect
    # on the metadata store itself, you have to use
    # the []= method to modify it.
    def attributes
      final = {}
      self.all.each { |md| final[md.meta_key] = md.meta_value }
      final
    end

    # This method sets several keys at once
    # in the metadata store; the hash +myhash+ will
    # be scanned and all its (key,value) pairs
    # will be used to store equivalent metadata
    # on the current ActiveRecord object.
    def attributes=(myhash)
      myhash.each do |k,v| 
        self[k]=v
      end
    end

    # This method sets the value of
    # the metadata key +mykey+ to
    # +myval+ for the current ActiveRecord
    # object. If +myval+ is nil, the key
    # will be deleted just like in delete().
    def []=(mykey,myval)
      return delete(mykey) if myval.nil?
      set_attribute(mykey,myval)
    end

    # This method gets the value of
    # the metadata key +mykey+ for
    # the current ActiveRecord object.
    def [](mykey)
      get_attribute(mykey)
    end

    # This method deletes the value of
    # the metadata key +mykey+ for
    # the current ActiveRecord object,
    # and return the original value that
    # was associated with it.
    def delete(mykey)
      delete_attribute(mykey)
    end

    # Returns all the MetaDataStore objects associated
    # with the current ActiveRecord object.
    def all #:nodoc:
      self.md_cache.values
    end



    ###################################################################
    # Internal Protected MetaData API
    ###################################################################

    protected

    # Reloads the cached set of MetaDataStore objects
    # associated with the current ActiveRecord object.
    def reload_cache #:nodoc:
      meta_data_records = MetaDataStore.scoped( :conditions => { :ar_id => self.ar_id, :ar_class => self.ar_class } )
      self.md_cache     = meta_data_records.index_by { |ar| ar.meta_key }
    end

    def set_attribute(mykey,myval) #:nodoc
      return delete_attribute(mykey) if myval.nil?
      mykey = mykey.to_s
      md = self.md_cache[mykey] || MetaDataStore.new( :ar_id => self.ar_id, :ar_class => self.ar_class, :meta_key => mykey )
      md_cache[mykey] = md
      md.meta_value   = myval
      md.save!
      myval
    end

    def get_attribute(mykey) #:nodoc
      mykey = mykey.to_s
      md = md_cache[mykey]
      return nil unless md
      md.meta_value
    end

    def delete_attribute(mykey) #:nodoc:
      mykey = mykey.to_s
      md = md_cache[mykey]
      return nil unless md
      orig = md.meta_value
      md.destroy
      return orig
    end

  end



  ###################################################################
  # ActiveRecord MetaData API Extensions (Instance Methods)
  ###################################################################

  # This is the main entry point to the current
  # ActiveRecord object's metadata store. It
  # returns an object of the class ActRecMetaData::MetaDataHandler
  # on which you can call methods to set or get
  # metadata associated with the ActiveRecord object.
  # See the methods in MetaDataHandler for more info.
  def meta
    cb_error "Cannot manage metadata on the metadata store itself!" if self.is_a?(MetaDataStore)
    cb_error "Cannot manage metadata on an object that hasn't been saved yet." unless self.id
    @meta ||= MetaDataHandler.new(self.id, self.class.to_s)
  end

  # Destroy the metadata associated with an ActiveRecord.
  # This is usually called automatically as a +after_destroy+
  # callback when the record is destroyed, but it can be
  # called manually too.
  def destroy_all_meta_data
    return true if self.is_a?(MetaDataStore)
    allmeta = self.meta.all
    @meta = nil
    return true unless allmeta
    allmeta.each { |m| m.destroy_without_callbacks }
    true
  end

  ###################################################################
  # ActiveRecord MetaData API Extensions (Class Methods)
  ###################################################################

  module ClassMethods

    #
    # This method returns an array of all ActiveRecord objects
    # of the current class (or its subclasses) that have the key +mykey+ set to +myval+
    # (or +mykey+ can be any value if +myval+ is set to nil).
    # The options hash can be used to further refine the find
    # operation.
    #
    # Example: if we have a model of Authors with metadata about them,
    # we can find the authors born in 1932 with
    #
    #   list1932 = Author.find_all_by_meta_data(:birthyear, 1932)
    #
    # If the Author model has an attribute :lastname, we can make the
    # search more specific with
    #
    #   list1932 = Author.find_all_by_meta_data(:birthyear, 1932,
    #                     :conditions => { :lastname => 'Johnson' })
    #
    def find_all_by_meta_data(mykey,myval=nil,options={})
      cb_error "Cannot search for MetaDataStore objects!"     if     self <= MetaDataStore
      cb_error "Search key must be defined!"                  if     mykey.nil?
      mykey = mykey.to_s
      subclasses = [ self.to_s ] + self.subclasses.map { |sc| sc.name.to_s }
      conditions = { :ar_class => subclasses, :meta_key => mykey }
      conditions[:meta_value] = myval unless myval.nil?
      matched = MetaDataStore.find(:all, :conditions => conditions)
      objects = matched.map do |md|
        md_ar_id    = md.ar_id
        md_ar_class = md.ar_class
        found_class = Class.const_get(md_ar_class)
        obj = found_class.find(md_ar_id, options.dup) rescue nil # NEEDS DUP!
        obj
      end
      objects.compact!
      return objects
    end

  end # ClassMethods module

end # ActRecMetaData module
