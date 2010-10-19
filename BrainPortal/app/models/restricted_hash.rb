
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

   # This must be a 'Class Instance Variable', not a class variable.
   @allowed_keys = {}

   # Initialize the list of allowed keys for your hash.
   # This methods requires an array of legal keys (usually,
   # symbols or strings).
   #
   #   class X < RestrictedHash
   #     self.allowed_keys= [ :abc, :def ]
   #   end
   def self.allowed_keys=(keys_list)
     # Hashing it all
     keys_list = keys_list[0] if keys_list.size == 1 && keys_list[0].is_a?(Array) # Alt API compatibility
     @allowed_keys = keys_list.inject({}) { |keys,myattr| keys[myattr] = true; keys }
   end

   # Returns the list of allowed keys for your hash,
   # as you supplied to allowed_keys=() (but not
   # necessarily in the same order). If given any
   # arguments, it acts the same as allowed_keys=(keys_list)
   # before returning the new set of keys. This makes it
   # useful to invoke as a directive in a class:
   #
   #   class X < RestrictedHash
   #     allowed_keys :abc, :def
   #   end
   def self.allowed_keys(*keys_list)
     if keys_list && keys_list.size > 0
       self.allowed_keys=keys_list
     end
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

   # Returns the list of allowed keys for your hash,
   # as you supplied to allowed_keys=() (but not
   # necessarily in the same order). Unlike the class
   # method of the same name, you can't change the set
   # of allowed keys with this instance method.
   def allowed_keys
     self.class.allowed_keys
   end

   # This method is a utility that allows you to
   # create a single instance of a RestrictedHash
   # belonging to an anonymous subclass of RestrictedHash
   # created especially for that instance. The +keys_list+
   # is the set of restricted keys you want.
   #
   #   my_special_hash = RestrictedHash.builder([ :abc, :def ])
   #   my_special_hash[:abc] = 3  # works
   #   my_special_hash[:xyz] = 5  # fails, as :xyz not allowed.
   #
   # Note that the method can be invoked with a list of attribute
   # names, just as well:
   #
   #   my_special_hash = RestrictedHash.builder( :abc, :def )
   def self.builder(*keys_list)
     cb_error "Need non_empty key list." unless keys_list.is_a?(Array) && keys_list.size > 0
     built_class = Class.new(self)
     built_class.allowed_keys = keys_list
     built_class.new
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

# This method is a shorthand for RestrictedHash.builder(args)
def RestrictedHash(*args)
  RestrictedHash.builder(*args)
end

