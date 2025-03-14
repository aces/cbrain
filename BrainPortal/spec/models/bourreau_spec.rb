
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

require 'rails_helper'

describe Bourreau do
  let(:bourreau) { create(:bourreau) }

  describe "#tools" do
    it "should return the tools associated with this bourreaux" do
      tool = create(:tool, :tool_configs => [create(:tool_config, :tool => nil, :bourreau_id => bourreau.id)])
      expect(bourreau.tools).to match_array([tool])
    end
  end
  describe "#global_tool_config" do
    it "should return the global tool config" do
      tool_config = create(:tool_config, :bourreau_id => bourreau.id, :tool_id => nil)
      expect(bourreau.global_tool_config).to eq(tool_config)
    end
  end
  describe "#scir_class" do
    it "should raise an exception if cluster management class invalid" do
      bourreau.cms_class = "invalid"
      expect{bourreau.scir_class}.to raise_error(CbrainError, /Bourreau record invalid/)
    end
    it "should return the Scir class" do
      bourreau.cms_class = "ScirSge"
      expect(bourreau.scir_class).to eq(ScirSge)
    end
  end
  describe "#scir_session" do
    it "should create a Scir session" do
      expect(Scir).to receive(:session_builder)
      bourreau.scir_session
    end
  end
  describe "#start" do
    before(:each) do
      allow(bourreau).to receive(:has_remote_control_info?).and_return(true)
      allow(RemoteResource).to receive_message_chain(:current_resource, :is_a?).and_return(true)
      allow(bourreau).to receive(:start_tunnels).and_return(true)
      allow(bourreau).to receive(:write_to_remote_shell_command)
      allow(File).to receive(:read).and_return("Bourreau Started")
      allow(File).to receive(:unlink)
    end
    it "should set online to true" do
      bourreau.online = false
      expect do
        bourreau.start
      end.to change{ bourreau.online }.to(true)
    end
    it "should return false if bourreau doesn't have remote control info'" do
      allow(bourreau).to receive(:has_remote_control_info?).and_return(false)
      expect(bourreau.start).to be_falsey
    end
    it "should return false if not called from a portal" do
      allow(RemoteResource).to receive_message_chain(:current_resource, :is_a?).and_return(false)
      expect(bourreau.start).to be_falsey
    end
    it "should return false if unable to start ssh tunnels" do
      allow(bourreau).to receive(:start_tunnels).and_return(false)
      expect(bourreau.start).to be_falsey
    end
    it "should remotely launch the bourreau server" do
      expect(bourreau).to receive(:write_to_remote_shell_command)
      bourreau.start
    end
    it "should return true if the server launch was successful" do
      expect(bourreau.start).to be_truthy
    end
    it "should return false if the server launch failed" do
      allow(File).to receive(:read).and_return("Something wrong")
      expect(bourreau.start).to be_falsey
    end
  end
  describe "#stop" do
    before(:each) do
      allow(bourreau).to receive(:has_remote_control_info?).and_return(true)
      allow(RemoteResource).to receive_message_chain(:current_resource, :is_a?).and_return(true)
      allow(bourreau).to receive(:start_tunnels).and_return(true)
      allow(bourreau).to receive(:read_from_remote_shell_command).and_yield(double("io", :read => "Bourreau Stopped"))
      allow(bourreau).to receive(:stop_tunnels)
    end
    it "should return false if bourreau doesn't have remote control info'" do
      allow(bourreau).to receive(:has_remote_control_info?).and_return(false)
      expect(bourreau.stop).to be_falsey
    end
    it "should return false if not called from a portal" do
      allow(RemoteResource).to receive_message_chain(:current_resource, :is_a?).and_return(false)
      expect(bourreau.stop).to be_falsey
    end
    it "should return false if unable to start ssh tunnels" do
      allow(bourreau).to receive(:start_tunnels).and_return(false)
      expect(bourreau.stop).to be_falsey
    end
    it "should remotely shut down the bourreau server" do
      expect(bourreau).to receive(:read_from_remote_shell_command)
      bourreau.stop
    end
    it "should return true if the server shutdown was successful" do
      expect(bourreau.stop).to be_truthy
    end
    it "should return false if the server shutdown failed" do
      allow(bourreau).to receive(:read_from_remote_shell_command).and_yield(double("io", :read => "Something wrong"))
      expect(bourreau.stop).to be_falsey
    end
  end
  describe "#remote_resource_info" do
    let(:bourreau_info) {double("bourreau_info").as_null_object}
    before(:each) do
      allow(IO).to receive(:popen)
      allow(RemoteResourceInfo).to receive(:new).and_return(bourreau_info)
    end
    it "should raise an exception (not meant to be used on the portal side)" do
      expect{Bourreau.remote_resource_info}.to raise_error(ActiveRecord::RecordNotFound, /Couldn't find Bourreau/)
    end
  end
  describe "#send_command_get_task_outputs" do
    before(:each) do
      allow(bourreau).to receive(:send_command)
    end
    it "should create a 'get task outputs' command" do
      expect(RemoteCommand).to receive(:new).with(hash_including(:command => 'get_task_outputs'))
      bourreau.send_command_get_task_outputs("task_id")
    end
    it "should send the command" do
      expect(bourreau).to receive(:send_command)
      bourreau.send_command_get_task_outputs("task_id")
    end
  end
end

