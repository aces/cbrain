
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
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

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

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
    # Used by the command 'alter_tasks' and 'get_task_outputs'.
    :task_ids,

    # A new task status for the tasks affected by 'alter_tasks'
    # Must be one of 'Suspended', "On Hold', 'Queued', 'Recover', etc.
    # Only some statuses are valid, and these only when the tasks
    # are already in some particular states. See process_command_alter_tasks().
    :new_task_status,
    :new_bourreau_id,  # for when new_task_status is 'Duplicate'
    :archive_data_provider_id, # when new_task_status is 'ArchiveWorkdirAsFile'

    # -------- GET TASK OUTPUTS PARAMETERS --------
    # For these, :task_ids is expected to contain a single ID
    :run_number,      # supplied by queryier
    :stdout_lim,      # number of lines to return
    :stderr_lim,      # number of lines to return
    :cluster_stdout,  # filled by receiver
    :cluster_stderr,  # filled by receiver
    :script_text,     # filled by receiver

    # -------- CLEAN CACHE PARAMETERS --------

    # Which users are 'involved' in the command; only used for clean_cache
    # right now. Numeric ids as string. "3,4,5" or "all".
    :user_ids,

    # Not really used right now
    :group_ids,

    # Userfile types, single string with commas.
    :types,

    # Date of effect; for clean_cache it means cleans files older than this..
    :before_date,  # Time object
    # ... but younger than this are erased.
    :after_date,   # Time object

    # -------- CHECK DATA PROVIDERS PARAMETERS --------

    :data_provider_ids,    # an input for the command, a list of DP ids as string. "1,2,3"

    # -------- KEEP USER IDS --------

    :requester_user_id,    # an input for the command, generally the current_user

  ]

  # Transforms the object into a pretty report
  def inspect #:nodoc:
    report  = "\n"
    #report += "RemoteCommand:\n"
    #report += "\n"
    report += "  Command: #{self.command}\n"
    report += "    Status: #{command_execution_status}\n"
    if self.command.to_s =~ /alter_tasks|get_task_outputs/
      report += "    Task-IDs: #{self.task_ids}\n"
    end
    if self.command.to_s == 'alter_tasks'
      report += "    New-Task_Status: #{self.new_task_status}\n"
      report += "    New-Bourreau-ID: #{self.new_bourreau_id}\n"
      report += "    Archive-DataProvider-ID: #{self.archive_data_provider_id}\n"
    elsif self.command.to_s == 'get_task_outputs'
      report += "    Run-Number: #{self.run_number}\n"
      report += "    Cluster-Stdout: #{(self.cluster_stdout || "").size} bytes\n"
      report += "    Cluster-Stderr: #{(self.cluster_stderr || "").size} bytes\n"
      report += "    Script-Text: #{(self.script_text || "").size} bytes\n"
    elsif self.command.to_s == 'clean_cache'
      report += "    User-IDs: #{self.user_ids}\n"
      report += "    Group-IDs: #{self.group_ids}\n"
      report += "    Types: #{self.types}\n"
      report += "    Before-Date: #{self.before_date}\n"
      report += "    After-Date: #{self.after_date}\n"
    elsif self.command.to_s == 'check_data_providers'
      report += "    Data-Provider-IDs: #{(self.data_provider_ids || []).join(", ")}\n"
    end
    report += "\n"
    report += "  Transport:\n"
    report += "    ID: #{self[:id]}\n"   # must use [] method here
    report += "    Sender-Token: #{self.sender_token}\n"
    report += "    Receiver-Token: #{self.receiver_token}\n"

    return report
  end

end

