
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
# Attribute values can be saved to, and retrieved from the record using
# two equivalent syntax:
#
#   obj.myattr   = value
#   obj[:myattr] = value
#   value = obj.myattr
#   value = obj[:myattr]
class RestrictedHash < Hash

   Revision_info="$Id$"

   # First time in my life I use a 'Class Instance Variable'
   @allowed_keys = {}

   # Initialize the list of allowed keys for your hash.
   # This methods requires an array of legal keys (usually,
   # symbols or strings).
   def self.allowed_keys=(keys_list)
     # Hashing it all
     @allowed_keys = keys_list.inject({}) { |keys,myattr| keys[myattr] = true; keys }
   end

   # Returns the list of allowed keys for your hash,
   # as you supplied to allowed_keys=() (but not
   # necessarily in the same order).
   def self.allowed_keys
     @allowed_keys.keys
   end

   # Returns true if +myattr+ is one of the allowed keys
   # in this restricted hash class.
   def self.key_is_allowed?(myattr)
     @allowed_keys[myattr]
   end

   # Returns true if +myattr+ is one of the allowed keys
   # in this restricted hash object.
   def key_is_allowed?(myattr)
     self.class.key_is_allowed?(myattr)
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

   # Implements the hash syntax for setting attributes
   def []=(myattr,val) #:nodoc:
     myattr = myattr.to_sym if myattr.is_a?(String)
     cb_error "Illegal attribute '#{myattr}'." unless key_is_allowed?(myattr)
     super(myattr,val)
   end

   # Implements the hash syntax for getting attributes
   def [](myattr) #:nodoc:
     cb_error "Illegal attribute '#{myattr}'." unless key_is_allowed?(myattr)
     super(myattr)
   end

   # For compatibility method with the Hash class
   def merge!(attributes={}) #:nodoc:
     attributes.each do |myattr, val|
       self[myattr]=val
     end
     self
   end

   # For compatibility method with the Hash class
   def merge(attributes={}) #:nodoc:
     mynew = self.dup
     attributes.each do |myattr, val|
       mynew[myattr]=val
     end
     mynew
   end

   # Returns a XML version of the restricted hash, with the root tag
   # being the class name.
   def to_xml(options = {})
     super(options.dup.merge({ :root => self.class }))
   end

   # Implements the method syntax for accessing attributes:
   #   puts obj.myattr
   #   obj.myattr = value
   def method_missing(name,*args) #:nodoc:
     # 'name' will be provided by Ruby as :myattr or :myattr=
     myattr = name.to_s
     if myattr.sub!(/=$/,"")
       self[myattr.to_sym] = args[0]
     else
       self[name]
     end
   end

end

