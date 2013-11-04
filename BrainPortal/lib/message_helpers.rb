
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

    type   = generic_human_type(success_list.first)

		# Send message
    Message.send_message(receiver,
      :message_type  => :notice,
      :header        => header,
      :variable_text => "For #{view_pluralize(success_list.count,type)}"  
    )
  end

  # Send a generic error message. 
  # Each error message is displayed with the number of objects that
  # triggered the error and list it.
  def error_message_sender(header,failed_list,receiver=current_user)
    # Return the first object of failed_list
    object = failed_list.first.last.first
    type   = generic_human_type(object)
    # Define path 
    path   = object.class.sti_root_class.to_s.underscore.pluralize
    if object.is_a?(RemoteResource)
      path = "bourreaux"
    elsif object.is_a?(CbrainTask)
      path = "tasks"
		end

    report      = ""
    failed_list.each do |m,objects|
      message = m.dup
      message.sub!(/\.$/,"")
      report     += "For #{view_pluralize(objects.size,type)}, #{message}:\n"
      report     += objects.sort_by(&:name).map { |o| "[[#{o.name}][/#{path}/#{o.id}]]\n" }.join("")
    end
    
    Message.send_message(receiver,
      :message_type  => :error,
      :header        => header,
      :variable_text => report  
    )
  end

  private

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
