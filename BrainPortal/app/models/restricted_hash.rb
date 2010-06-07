
#
# CBRAIN Project
#
# Restricted Hash class; NOT AN ACTIVE RECORD!
#
# Original author: Pierre Rioux
#
# $Id$
#

# This model encapsulates a record with a precise list
# of attributes. This is not an ActiveRecord, it's a
# subclass of Hash. The complete list of allowed keys
# need to be set once by calling the class
# method allowed_keys() .
#
# Values can be saved to, and retrieved from the record using
# two equivalent syntax:
#
#   obj.fieldname   = value
#   obj[:fieldname] = value
#   value = obj.fieldname
#   value = obj[:fieldname]
class RestrictedHash < Hash

   Revision_info="$Id$"

   # First time in my life I use a 'Class Instance Variable'
   @allowed_keys = {}

   # Initialize the list of allowed keys for your hash.
   # This methods requires an array of legal keys (usually,
   # symbols or strings).
   def self.allowed_keys=(keys_list)
     # Hashing it all
     @allowed_keys = keys_list.inject({}) { |keys,field| keys[field] = true; keys }
   end

   # Returns the list of allowed keys for your hash,
   # as you supplied to allowed_keys=() (but not
   # necessarily in the same order).
   def self.allowed_keys
     @allowed_keys.keys
   end

   # Returns true if +field+ is one of the allowed keys
   # in this restricted hash class.
   def self.key_is_allowed?(field)
     @allowed_keys[field]
   end

   # Returns true if +field+ is one of the allowed keys
   # in this restricted hash object.
   def key_is_allowed?(field)
     self.class.key_is_allowed?(field)
   end

   # Unlike a normal hash, this class allows easy
   # initialization using another hash, like this:
   #
   #   restrictedhash = RestrictedHashSubclass.new(
   #      :key1 => val1,
   #      :key2 => val2
   #   )
   #
   # This makes it useful in combination with the
   # 'attributes' method of ActiveRecord.
   def initialize(attributes = {})
     merge!(attributes)
   end

   def []=(field,val) #:nodoc:
     field = field.to_sym if field.is_a?(String)
     cb_error "Illegal field '#{field}'." unless key_is_allowed?(field)
     super(field,val)
   end

   def [](field) #:nodoc:
     cb_error "Illegal field '#{field}'." unless key_is_allowed?(field)
     super(field)
   end

   def merge!(attributes={}) #:nodoc:
     attributes.each do |field, val|
       self[field]=val
     end
     self
   end

   def merge(attributes={}) #:nodoc:
     mynew = self.dup
     attributes.each do |field, val|
       mynew[field]=val
     end
     mynew
   end

   # Returns a XML version of the hash, with the root tag
   # being the class name.
   def to_xml(options = {})
     super(options.dup.merge({ :root => self.class }))
   end

   def method_missing(name,*args) #:nodoc:
     # name will be provided by ruby as :field or :field=
     field = name.to_s
     if field.sub!(/=$/,"")
       self[field.to_sym] = args[0]
     else
       self[name]
     end
   end

end

