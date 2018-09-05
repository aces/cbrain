
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

# Controls Controller for RemoteResources
#
# This controller provides querying and controlling
# of the current RemoteResource. Information flows
# back and forth on an ActiveResource channel
# called Control.
#
# The kind of actions that it supports is very limited.
# We support 'show' and 'create' only.
class ControlsController < ApplicationController

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  api_available

  # The 'show' action responds to only a single ID,
  # either 'info' or 'ping', and returns a RemoteResourceInfo record.
  def show
    keyword = params[:id]

    if keyword == 'info' || keyword == 'ping'
      myself = RemoteResource.current_resource
      $0 = "CBRAIN Server #{myself.class} #{myself.name} #{CBRAIN::Instance_Name}" # to override puma's process name
      @info  = myself.remote_resource_info(keyword)
      respond_to do |format|
        format.html { head :method_not_allowed }
        format.xml  { render :xml => @info.to_xml }
      end
      return
    end

    respond_to do |format|
      format.html { head :method_not_allowed }
      format.xml  { head :method_not_allowed }
    end
  end

  # The 'create' action receives a Control object
  # encapsulating a RemoteCommand object.
  # It assigns an arbitrary, unique,
  # transient ID to the command object.
  # After the object's command is executed, the
  # command object is returned to the sender,
  # so that information can be sent back.
  #
  # The command object is validated for proper sender/
  # receiver credentials, and then it is passed on
  # to the RemoteResource object representing
  # the current Rails application for processing.
  def create
    @@command_counter ||= 0
    @@command_counter += 1
    command = RemoteCommand.new(params[:control]) # a HASH
    command.id = "#{@@command_counter}-#{Process.pid}-#{Time.now.to_i}" # not useful right now.
    if process_command(command)
      command.command_execution_status = "OK"
    else
      command.command_execution_status = "FAILED"
    end
    respond_to do |format|
      format.html { head :method_not_allowed }
      format.xml do
        headers['Location'] = url_for(:controller => "controls", :action => nil, :id => command[:id])
        render :xml => command.to_xml, :status => :created
      end
    end
  rescue => e  # TODO : inform client somehow ?
    puts "Exception in create command: #{e.message}"
    puts e.backtrace[0..15].join("\n")
    respond_to do |format|
      format.html { head :method_not_allowed }
      format.xml  { head :method_not_allowed }
    end
  end

  #######################################################################
  # Command processing
  #######################################################################

  private

  def process_command(command) #:nodoc:
    puts "Received COMMAND: #{command.inspect}" rescue "Exception in inspecting command?!?"

    myself = RemoteResource.current_resource
    myself.class.process_command(command)

    return true

  rescue => exception
    myself ||= RemoteResource.current_resource
    Message.send_internal_error_message(User.find_by_login('admin'),
      "RemoteResource #{myself.name} raised exception processing a message.", # header
      exception,
      command
    )
    return false
  end

end
