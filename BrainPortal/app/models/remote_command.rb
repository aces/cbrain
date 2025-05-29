
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

    # Command keyword, one of 'stop_workers', 'start_workers',
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

    # -------- GET TASK OUTPUTS PARAMETERS --------

    :task_id,
    :run_number,      # supplied by queryier
    :stdout_lim,      # number of lines to return
    :stderr_lim,      # number of lines to return
    :cluster_stdout,  # filled by receiver
    :cluster_stderr,  # filled by receiver
    :script_text,     # filled by receiver
    :runtime_info,    # filled by receiver

    # -------- CHECK DATA PROVIDERS PARAMETERS --------

    :data_provider_ids,    # an input for the command, a list of DP ids as string. "1,2,3"

    # -------- COMMAND USER ID --------

    :requester_user_id,    # an input for the command, generally the current_user

    # -------- SSH KEY PUSH PARAMETERS --------

    :ssh_key_pub, :ssh_key_priv, # when installing new ssh key


    # -------- ERROR TRACES --------

    :exception_class,      # filled by receiver if an exception occured
    :exception_message,    # filled by receiver
    :backtrace,            # array of lines

  ]

  # Transforms the object into a pretty report
  def inspect #:nodoc:
    report  = "\n"
    report += "RemoteCommand: #{self.command}\n"
    report += "  Status: #{command_execution_status}\n"
    if self.command.to_s == 'get_task_outputs'
      report += "  Task-ID: #{self.task_id}\n"
      report += "  Run-Number: #{self.run_number}\n"
      report += "  Cluster-Stdout: #{(self.cluster_stdout || "").size} bytes\n"
      report += "  Cluster-Stderr: #{(self.cluster_stderr || "").size} bytes\n"
      report += "  Script-Text: #{(self.script_text || "").size} bytes\n"
    elsif self.command.to_s == 'check_data_providers'
      report += "  Data-Provider-IDs: #{(self.data_provider_ids || []).join(", ")}\n"
    end

    report += "\n"
    report += "  Transport:\n"
    report += "    ID: #{self[:id]}\n"   # must use [] method here
    report += "    Sender-Token: #{self.sender_token}\n"
    report += "    Receiver-Token: #{self.receiver_token}\n"

    if self.exception_class.present?
      report += "\n"
      report += "  Exception:\n"
      report += "    Class: #{self.exception_class}\n"
      report += "    Message: #{self.exception_message}\n"
      (self.backtrace.presence || []).each do |line|
        report += "    -> #{line}\n"
      end
    end

    return report
  end

end

