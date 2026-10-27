
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

# Helpers to send generic notice message and error message
module MessageHelpers

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Send a generic notice message, with the succes count.
  def notice_message_sender(header,success_list,receiver=current_user)

    # Send message
    Message.send_message(receiver,
      :message_type  => :notice,
      :header        => header,
      :variable_text => message_count_prefix(success_list)
    )
  end

  # Send a generic error message.
  # Each error message is displayed with the number of objects that
  # triggered the error and list it.
  def error_message_sender(header,failed_list,receiver=current_user)

    # Return the first object of failed_list
    object = failed_list.first.last.first
    # Define path
    path   = object.class.sti_root_class.to_s.underscore.pluralize
    if object.is_a?(RemoteResource)
      path = "bourreaux"
    elsif object.is_a?(CbrainTask)
      path = "tasks"
    end

    report      = ""
    failed_list.each do |message,objects|
      report     += "#{message_count_prefix(objects)}, #{message}:\n"
      report     += objects.sort_by(&:name).map { |o| "[[#{o.name}][/#{path}/#{o.id}]]\n" }.join("")
    end

    Message.send_message(receiver,
      :message_type  => :error,
      :header        => header,
      :variable_text => report
    )
  end

  private

  def message_count_prefix(objects)
    return I18n.t('task_message_helpers.for_tasks', :count => objects.size) if objects.first.is_a?(CbrainTask)
    "For #{view_pluralize(objects.size, generic_human_type(objects.first))}"
  end

  def generic_human_type(object) #:nodoc:
    type = object.class.pretty_type

    if object.is_a?(Userfile)
      type = "file"
    elsif object.is_a?(CbrainTask)
      type = "task"
    end

    return type
  end

end
