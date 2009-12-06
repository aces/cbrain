
#
# CBRAIN Project
#
# Remote Command class; NOT AN ACTIVE RECORD!
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
# encode the kind of commands that a RemoteResource can
# send to another RemoteResource, using the Controls
# controller and the Control ActiveResource, which
# are used by all CBRAIN Rails applications.
class RemoteCommand < RestrictedHash

   Revision_info="$Id$"

   # List of allowed keys in the hash
   self.allowed_keys=[

     # An ID, usually assigned by the receiver.
     :id,

     # Command keyword, one of 'clean_cache', 'stop_workers', 'start_workers'
     :command,

     # Auth token of originator (for security)
     :sender_token,

     # Auth token of the current remote resource (for security)
     :receiver_token,

     # Which users are 'involved' in the command; only used for clean_cache
     # right now. Numeric ids as string. "3,4,5" or "all".
     :user_ids,

     # Not really used right now
     :group_ids,

     # Date of effect; for clean_cache it means cleans files older than this
     :before_date,  # Time object
     :after_date,   # Time object; not used right now.

   ]

end

