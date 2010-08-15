
#
# CBRAIN Project
#
# Remote Resource Info class; NOT AN ACTIVE RECORD!
#
# Original author: Pierre Rioux
#
# $Id$
#

# This model encapsulates a record with a precise list
# of attributes. This is not an ActiveRecord, it's a
# subclass of Hash. See RestrictedHash for more info.
# Note that the attributes are used for an ActiveResource
# request, and therefore must be filled with strings.
#
# The attributes in this particular model are used to
# report on the state of a RemoteResource, when queried
# by another RemoteResource. This is performed by
# using the Controls controller and the Control
# ActiveResource, which are used by all CBRAIN
# Rails applications.
class RemoteResourceInfo < RestrictedHash

   Revision_info="$Id$"

   # List of allowed keys in the hash
   self.allowed_keys=[

     # General fields about a Remote Resource
     :id, :name,            # Rails app RemoteResource info
     :uptime,               # Rails app uptime in seconds

     # Host info
     :host_name,            # Value returned by Socket.gethostname
     :host_uname,           # Output of 'uname -a' command
     :host_ip,              # IP address as "1.2.3.4"
     :host_uptime,          # Output of 'uptime' command
     :ssh_public_key,

     # Svn info (Rails app)
     :revision,             # From 'svn info' on disk AT QUERYTIME
     :lc_author,            # From 'svn info' on disk AT QUERYTIME
     :lc_rev,               # From 'svn info' on disk AT QUERYTIME
     :lc_date,              # From 'svn info' on disk AT QUERYTIME
     :starttime_revision,   # From 'svn info' on disk AT STARTTIME

     # Bourreau-specific fields
     :bourreau_cms, :bourreau_cms_rev,
     :tasks_max,    :tasks_tot,

     # Bourreau Worker Svn info
     :worker_pids,
     :worker_lc_author,
     :worker_lc_rev,
     :worker_lc_date

   ]

   # Returns a dummy record filled with
   # mostly '???' for each field.
   def self.dummy_record

     dummy = self.new()
     self.allowed_keys.each do |field|
       dummy[field] = "???"
     end

     dummy.id               = 0
     dummy.bourreau_cms_rev = Object.revision_info # means 'unknown'

     dummy
   end
   
   # Returns a default value of '???' for any attributes
   # not set.
   def [](key)
     super || "???"
   end

end

