
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

require 'spec_helper'

describe Bourreau do
  let(:bourreau) {Factory.create(:bourreau)}
  describe "#tools" do
    it "should return the tools associated with this bourreaux" do
      tool = Factory.create(:tool, :tool_configs => [Factory.create(:tool_config, :tool => nil, :bourreau_id => bourreau.id)])
      bourreau.tools.should =~ [tool]
    end
  end
  describe "#global_tool_config" do
    it "should return the global tool config" do
      tool_config = Factory.create(:tool_config, :bourreau_id => bourreau.id, :tool_id => nil)
      bourreau.global_tool_config.should == tool_config
    end
  end
  describe "#scir_class" do
    it "should raise an exception if cluster management class invalid" do
      bourreau.cms_class = "invalid"
      lambda{bourreau.scir_class}.should raise_error
    end
    it "should return the Scir class" do
      bourreau.cms_class = "ScirSge"
      bourreau.scir_class.should == ScirSge
    end
  end
  describe "#scir_session" do
    it "should create a Scir session" do
      Scir.should_receive(:session_builder)
      bourreau.scir_session
    end
  end
  describe "#start" do
    before(:each) do
      bourreau.stub!(:has_remote_control_info?).and_return(true)
      RemoteResource.stub_chain(:current_resource, :is_a?).and_return(true)
      bourreau.stub!(:start_tunnels).and_return(true)
      bourreau.stub!(:write_to_remote_shell_command)
      File.stub!(:read).and_return("Bourreau Started")
      File.stub!(:unlink)
    end
    it "should set online to true" do
      bourreau.online = false
      lambda do
        bourreau.start
      end.should change{ bourreau.online }.to(true)
    end
    it "should return false if bourreau doesn't have remote control info'" do
      bourreau.stub!(:has_remote_control_info?).and_return(false)
      bourreau.start.should be_false
    end
    it "should return false if not called from a portal" do
      RemoteResource.stub_chain(:current_resource, :is_a?).and_return(false)
      bourreau.start.should be_false
    end
    it "should return false if unable to start ssh tunnels" do
      bourreau.stub!(:start_tunnels).and_return(false)
      bourreau.start.should be_false
    end
    it "should remotely launch the bourreau server" do
      bourreau.should_receive(:write_to_remote_shell_command)
      bourreau.start
    end
    it "should return true if the server launch was successful" do
      bourreau.start.should be_true
    end
    it "should return false if the server launch failed" do
      File.stub!(:read).and_return("Something wrong")
      bourreau.start.should be_false
    end
  end
  describe "#stop" do
    before(:each) do
      bourreau.stub!(:has_remote_control_info?).and_return(true)
      RemoteResource.stub_chain(:current_resource, :is_a?).and_return(true)
      bourreau.stub!(:start_tunnels).and_return(true)
      bourreau.stub!(:read_from_remote_shell_command).and_yield(double("io", :read => "Bourreau Stopped"))
      bourreau.stub!(:stop_tunnels)
    end
    it "should return false if bourreau doesn't have remote control info'" do
      bourreau.stub!(:has_remote_control_info?).and_return(false)
      bourreau.stop.should be_false
    end
    it "should return false if not called from a portal" do
      RemoteResource.stub_chain(:current_resource, :is_a?).and_return(false)
      bourreau.stop.should be_false
    end
    it "should return false if unable to start ssh tunnels" do
      bourreau.stub!(:start_tunnels).and_return(false)
      bourreau.stop.should be_false
    end
    it "should remotely shut down the bourreau server" do
      bourreau.should_receive(:read_from_remote_shell_command)
      bourreau.stop
    end
    it "should return true if the server shutdown was successful" do
      bourreau.stop.should be_true
    end
    it "should return false if the server shutdown failed" do
      bourreau.stub!(:read_from_remote_shell_command).and_yield(double("io", :read => "Something wrong"))
      bourreau.stop.should be_false
    end
  end
  describe "#remote_resource_info" do
    let(:bourreau_info) {double("bourreau_info").as_null_object}
    before(:each) do
      IO.stub!(:popen)
      RemoteResourceInfo.stub!(:new).and_return(bourreau_info)
    end
    it "should raise an exception (not meant to be used on the portal side)" do
      lambda{Bourreau.remote_resource_info}.should raise_error
    end
  end
  describe "#send_command_get_task_outputs" do
    before(:each) do
      bourreau.stub!(:send_command)
    end
    it "should create a 'get task outputs' command" do
      RemoteCommand.should_receive(:new).with(hash_including(:command => 'get_task_outputs'))
      bourreau.send_command_get_task_outputs("task_id")
    end
    it "should send the command" do
      bourreau.should_receive(:send_command)
      bourreau.send_command_get_task_outputs("task_id")
    end
  end
  describe "#send_command_alter_tasks" do
    before(:each) do
      bourreau.stub!(:send_command)
    end
    it "should create a 'get task outputs' command" do
      RemoteCommand.should_receive(:new).with(hash_including(:command => 'alter_tasks'))
      bourreau.send_command_alter_tasks("task_id", "New")
    end
    it "should send the command" do
      bourreau.should_receive(:send_command)
      bourreau.send_command_alter_tasks("task_id", "New")
    end
  end
end

