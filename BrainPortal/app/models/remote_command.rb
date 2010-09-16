
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

     # -------- GENERIC COMMAND PARAMETERS --------

     # An ID, usually assigned by the receiver.
     :id,

     # Command keyword, one of 'clean_cache', 'stop_workers', 'start_workers',
     # etc. On the receiving end, the method "process_command_#{:command}"
     # will be executed with the current command object.
     :command,

     # Will be set by receiver to "OK" or "FAILED", so that when
     # the command object is returned the sender will know.
     :command_execution_status,

     # Auth token of originator (for security)
     :sender_token,

     # Auth token of the current remote resource (for security)
     :receiver_token,

     # -------- ALTER TASKS PARAMETERS --------

     # Tasks affected, as a string of comma-separated task IDs.
     # Used by the command 'alter_tasks' and 'get_task_outpus'.
     :task_ids,

     # A new task status for the tasks affected by 'alter_tasks'
     # Most be one of 'Suspended', "On Hold', 'Queued', 'Recover', etc.
     # Only some statuses are valid on these only when the tasks
     # are already in some other states. See process_command_alter_tasks().
     :new_task_status,
     :new_bourreau_id,  # for when new_task_status is 'Duplicate'

     # -------- GET TASK OUTPUTS PARAMETERS --------
     # Uses :task_ids with a single ID expected in it
     :run_number,      # supplied by queryier
     :cluster_stdout,  # filled by receiver
     :cluster_stderr,  # filled by receiver
     :script_text,     # filled by receiver

     # -------- CLEAN CACHE PARAMETERS --------

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

