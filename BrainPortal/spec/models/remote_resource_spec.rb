
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

describe RemoteResource do
  let(:userfile)        {create(:single_file)}
  let(:remote_resource) {create(:remote_resource)}

  describe "#spaced_dp_ignore_patterns" do
    it "should return the ignore patterns as a space-separated string" do
      expect(remote_resource.spaced_dp_ignore_patterns).to match(/#{remote_resource.dp_ignore_patterns.join("\\s+")}/)
    end
  end
  describe "#spaced_dp_ignore_patterns=" do
    it "should update the ignore patterns" do
      remote_resource.spaced_dp_ignore_patterns = "a b c"
      expect(remote_resource.dp_ignore_patterns).to match_array(["a", "b", "c"])
    end
  end
  describe "#current_resource" do
    it "should return the resource representing the current app" do
      expect(RemoteResource.current_resource.id).to eq(CBRAIN::SelfRemoteResourceId)
    end
  end
  describe "#current_resource_db_config" do
    it "should return a hash with db configuration" do
      expect(RemoteResource.current_resource_db_config).to have_key("database")
    end
  end
  describe "#after_destroy" do
    it "should destroy all associated sync statuses" do
      syncstatus = SyncStatus.new(:remote_resource_id => remote_resource.id, :userfile_id => userfile.id)
      syncstatus.save!
      remote_resource.reload
      remote_resource.save!

      expect do
        remote_resource.destroy
      end.to change{ SyncStatus.count }.by(-1)
    end
  end
  describe "#proper_dp_ignore_patterns" do
    it "should be invalid if ignore patterns are not valid" do
      remote_resource.spaced_dp_ignore_patterns = "a * c"
      expect(remote_resource).to have(1).error_on(:spaced_dp_ignore_patterns)
    end
    it "should be invalid if ignore patterns in improper format" do
      remote_resource.dp_ignore_patterns = "a * c"
      expect(remote_resource).to have(1).error_on(:dp_ignore_patterns)
    end
    it "should allow saving if ignore patterns are valid" do
      remote_resource.spaced_dp_ignore_patterns = "a b c"
      expect(remote_resource).to be_valid
    end
  end
  describe "#dp_cache_path_valid" do
    it "should be valid if the cache path is absolute" do
      remote_resource.dp_cache_dir = "/absolute_path"
      expect(remote_resource).to be_valid
    end
    it "should be valid if the cache path hasn't been set yet" do
      remote_resource.dp_cache_dir = nil
      expect(remote_resource).to be_valid
    end
    it "should prevent saving if the cache path is not absolute" do
      remote_resource.dp_cache_dir = "not/absolute"
      remote_resource.save
      expect(remote_resource).to have(2).error_on(:dp_cache_dir)
    end
    context "on the Portal app" do
      let(:portal_resource) {RemoteResource.current_resource}
      before(:each) do
        allow(portal_resource).to receive(:dp_cache_dir).and_return("path")
      end

      it "should be valid if the cache path is valid" do
        allow(DataProvider).to receive(:this_is_a_proper_cache_dir!).and_return(true)
        allow(portal_resource).to receive(:dp_cache_dir).and_return("/path")
        expect(portal_resource).to be_valid
      end
      it "should be invalid if the cache path is invalid" do
        allow(DataProvider).to receive(:this_is_a_proper_cache_dir!).and_return(false)
        portal_resource.save
        expect(portal_resource.error_on(:dp_cache_dir).size).to eq(2)
      end
      it "should be invalid if the cache dir check raises an exception" do
        allow(DataProvider).to receive(:this_is_a_proper_cache_dir!).and_raise(StandardError)
        portal_resource.save
        expect(portal_resource.error_on(:dp_cache_dir).size).to eq(2)
      end
    end
  end
  describe "#ssh_master" do
    it "should create find or create an SSH master" do
      expect(SshMaster).to receive(:find_or_create)
      remote_resource.ssh_master
    end
  end
  describe "#start_tunnels" do
    let(:ssh_master) {double("ssh_master", :start => true, :is_alive? => false).as_null_object}
    before(:each) do
      allow(remote_resource).to receive(:ssh_master).and_return(ssh_master)
      allow(remote_resource).to receive(:has_ssh_control_info?).and_return(true)
      allow(remote_resource).to receive(:ssh_control_rails_dir).and_return("dir")
    end
    it "should return false if called on the Portal app" do
      portal_resource = RemoteResource.current_resource
      expect(portal_resource.start_tunnels).to be_falsey
    end
    it "should return false if offline" do
      remote_resource.online = false
      expect(remote_resource.start_tunnels).to be_falsey
    end
    it "should return false unless it has ssh control info" do
      allow(remote_resource).to receive(:has_ssh_control_info?).and_return(false)
      expect(remote_resource.start_tunnels).to be_falsey
    end
    it "should check if the master is alive" do
      expect(ssh_master).to receive(:is_alive?)
      remote_resource.start_tunnels
    end
    it "should return true if master is alive" do
      allow(ssh_master).to receive(:is_alive?).and_return(true)
      expect(remote_resource.start_tunnels).to be_truthy
    end
    it "should return false if ssh master start fails" do
      allow(ssh_master).to receive(:start).and_return(false)
      expect(remote_resource.start_tunnels).to be_falsey
    end
    it "should return true if all goes well" do
      expect(remote_resource.start_tunnels).to be_truthy
    end
    it "should delete tunnels" do
      expect(ssh_master).to receive(:delete_tunnels).at_least(:once)
      remote_resource.start_tunnels
    end
    it "should add a tunnel when db tunneling info is available" do
      expect(ssh_master).to receive(:add_tunnel).twice
      remote_resource.start_tunnels
    end
  end
  describe "#stop_tunnels" do
    before(:each) do
      allow(remote_resource).to receive(:has_ssh_control_info?).and_return(true)
    end
    it "should return false if called on the Portal app" do
      portal_resource = RemoteResource.current_resource
      expect(portal_resource.stop_tunnels).to be_falsey
    end
    it "should return false unless it has ssh control info" do
      allow(remote_resource).to receive(:has_ssh_control_info?).and_return(false)
      expect(remote_resource.stop_tunnels).to be_falsey
    end
    it "should stop the tunnels" do
      ssh_master = double("ssh_master")
      expect(ssh_master).to receive(:destroy)
      allow(remote_resource).to receive(:ssh_master).and_return(ssh_master)
      remote_resource.stop_tunnels
    end
  end
  describe "#has_ssh_control_info?" do
    before(:each) do
      remote_resource.ssh_control_user = "user"
      remote_resource.ssh_control_host = "host"
    end
    it "should return false if user is blank" do
      remote_resource.ssh_control_user = ""
      expect(remote_resource).not_to have_ssh_control_info
    end
    it "should return false if host is blank" do
      remote_resource.ssh_control_host = ""
      expect(remote_resource).not_to have_ssh_control_info
    end
    it "should return true if user and host are present" do
      expect(remote_resource).to have_ssh_control_info
    end
  end
  describe "#has_remote_control_info?" do
    before(:each) do
      allow(remote_resource).to receive(:has_ssh_control_info?).and_return(true)
      remote_resource.ssh_control_rails_dir = "dir"
    end
    it "should return true if ssh control info and rails dir are defined" do
      expect(remote_resource).to have_remote_control_info
    end
    it "should return false if no ssh control infor" do
      allow(remote_resource).to receive(:has_ssh_control_info?).and_return(false)
      expect(remote_resource).not_to have_remote_control_info
    end
    it "should return false if rails dir is blank" do
      remote_resource.ssh_control_rails_dir = ""
      expect(remote_resource).not_to have_remote_control_info
    end
  end
  describe "#read_from_remote_shell_command" do
    let(:ssh_master) {double("ssh_master", :is_alive? => true, :remote_shell_command_reader => nil)}
    before(:each) do
      allow(remote_resource).to receive(:ssh_master).and_return(ssh_master)
      allow(remote_resource).to receive(:has_ssh_control_info?).and_return(true)
      allow(remote_resource).to receive(:prepend_source_cbrain_bashrc)
    end
    it "should raise an exception if there is no ssh control info" do
      allow(remote_resource).to receive(:has_ssh_control_info?).and_return(false)
      expect{ remote_resource.read_from_remote_shell_command("bash_command") }.to raise_error(CbrainError, /No proper SSH/)
    end
    it "should raise an exception if ssh master is not alive" do
      allow(ssh_master).to receive(:is_alive?).and_return(false)
      expect{ remote_resource.read_from_remote_shell_command("bash_command") }.to raise_error(CbrainError, /No SSH master/)
    end
    it "should prepare the bash command" do
      expect(remote_resource).to receive(:prepend_source_cbrain_bashrc)
      remote_resource.read_from_remote_shell_command("bash_command")
    end
    it "should write to ssh master" do
      expect(ssh_master).to receive(:remote_shell_command_reader)
      remote_resource.read_from_remote_shell_command("bash_command")
    end
  end
  describe "#write_to_remote_shell_command" do
    let(:ssh_master) {double("ssh_master", :is_alive? => true, :remote_shell_command_writer => nil)}
    before(:each) do
      allow(remote_resource).to receive(:ssh_master).and_return(ssh_master)
      allow(remote_resource).to receive(:has_ssh_control_info?).and_return(true)
      allow(remote_resource).to receive(:prepend_source_cbrain_bashrc)
    end
    it "should raise an exception if there is no ssh control info" do
      allow(remote_resource).to receive(:has_ssh_control_info?).and_return(false)
      expect{ remote_resource.write_to_remote_shell_command("bash_command") }.to raise_error(CbrainError, /No proper SSH/)
    end
    it "should raise an exception if ssh master is not alive" do
      allow(ssh_master).to receive(:is_alive?).and_return(false)
      expect{ remote_resource.write_to_remote_shell_command("bash_command") }.to raise_error(CbrainError, /No SSH master/)
    end
    it "should prepare the bash command" do
      expect(remote_resource).to receive(:prepend_source_cbrain_bashrc)
      remote_resource.write_to_remote_shell_command("bash_command")
    end
    it "should write to ssh master" do
      expect(ssh_master).to receive(:remote_shell_command_writer)
      remote_resource.write_to_remote_shell_command("bash_command")
    end
  end
  describe "#valid_token?" do
    before(:each) do
      remote_resource.update_attributes(:cache_md5 => "valid")
    end
    it "should return true if the token is valid" do
      expect(RemoteResource.valid_token?("valid")).to be_truthy
    end
    it "should return nil if the token is invalid" do
       expect(RemoteResource.valid_token?("invalid")).to be_nil
    end
  end
  describe "#auth_token" do
    it "should return the cache md5" do
      expect(remote_resource.auth_token).to eq(remote_resource.cache_md5)
    end
  end
  describe "#is_alive?" do
    let(:info_object) {double("info_object")}

    before(:each) do
      allow(Rails.cache).to receive(:fetch).and_return(info_object)
    end
    it "should return false if offline" do
      remote_resource.update_attributes(:online =>  false)
      expect(remote_resource.is_alive?).to be_falsey
    end
    context "with a valid info object" do
      before(:each) do
        allow(info_object).to receive(:name).and_return("rr")
      end
      it "should return true" do
        expect(remote_resource.is_alive?).to be true
      end
    end
    context "with an invalid info object" do
      before(:each) do
        allow(info_object).to receive(:name).and_return("???")
      end
      it "should return false" do
        expect(remote_resource.is_alive?).to be_falsey
      end
    end

  end
  describe "#site" do
    it "should return a url" do
      expect(remote_resource.site).to match(/^http:\/\//)
    end
    it "should return a 'localhost' url if ssh control and active resource tunnel info given" do
      allow(remote_resource).to receive(:has_ssh_control_info?).and_return(true)
      expect(remote_resource.site).to match(/^http:\/\/localhost/)
    end
  end
  describe "#remote_resource_info (class method)" do
    before(:each) do
      allow(Kernel).to receive(:`)
      allow(Socket).to receive(:gethostname)
      allow(Socket).to receive(:gethostbyname).and_raise(StandardError)
      allow(IO).to     receive(:popen)
    end
    it "should get the host name" do
      expect(Socket).to receive(:gethostname)
      RemoteResource.remote_resource_info
    end
    it "should return the remote resource info" do
      portal_resource = RemoteResource.current_resource
      expect(RemoteResource.remote_resource_info).to include(:id => portal_resource.id, :name => portal_resource.name)
    end
  end
  describe "#remote_resource_info (instance method)" do
    before(:each) do
      #allow(remote_resource).to receive(:ssh_master).and_return(true)
      allow(remote_resource).to receive_message_chain(:ssh_master, :is_alive?).and_return(true)
      allow(remote_resource).to receive(:site).and_return("site")
    end
    it "should delegate to class method if called on model representing current app" do
      portal_resource = RemoteResource.current_resource
      expect(portal_resource.class).to receive(:remote_resource_info)
      portal_resource.remote_resource_info
    end
    it "should try to connect to the resource" do
      expect(Control).to receive(:find).and_return(double("control_info").as_null_object)
      remote_resource.remote_resource_info
    end
    it "should create a RemoteResourceInfo object if connention works" do
      allow(Control).to receive(:find).and_return(double("control_info").as_null_object)
      expect(RemoteResourceInfo).to receive(:new).and_return({})
      remote_resource.remote_resource_info
    end
    it "should create a dummy RemoteResourceInfo object if connection fails" do
      allow(Control).to receive(:find).and_raise(StandardError)
      expect(remote_resource.remote_resource_info).to eq(RemoteResourceInfo.dummy_record)
    end
  end
  describe "#info" do
    it "should delegate to class' #remote_resource_info method if called on model representing current app" do
      portal_resource = RemoteResource.current_resource
      expect(portal_resource.class).to receive(:remote_resource_info)
      portal_resource.info
    end
    it "should check if alive" do
      expect(remote_resource).to receive(:is_alive?).and_return(true)
      remote_resource.info
    end
    it "should return a dummy object if not alive" do
      allow(remote_resource).to receive(:is_alive?).and_return(false)
      expect(remote_resource.info).to eq(RemoteResourceInfo.dummy_record)
    end
  end
  describe "#send_command_start_workers" do
    it "should create a new start_workers RemoteCommand" do
      allow(remote_resource).to receive(:send_command)
      expect(RemoteCommand).to receive(:new).with hash_including(:command => "start_workers")
      remote_resource.send_command_start_workers
    end
    it "should send the command" do
      allow(RemoteCommand).to receive(:new)
      expect(remote_resource).to receive(:send_command)
      remote_resource.send_command_start_workers
    end
  end
  describe "#send_command_stop_workers" do
    it "should create a new stop_workers RemoteCommand" do
      allow(remote_resource).to receive(:send_command)
      expect(RemoteCommand).to receive(:new).with hash_including(:command => "stop_workers")
      remote_resource.send_command_stop_workers
    end
    it "should send the command" do
      allow(RemoteCommand).to receive(:new)
      expect(remote_resource).to receive(:send_command)
      remote_resource.send_command_stop_workers
    end
  end
  describe "#send_command_wakeup_workers" do
    it "should create a new wakeup_workers RemoteCommand" do
      allow(remote_resource).to receive(:send_command)
      expect(RemoteCommand).to receive(:new).with hash_including(:command => "wakeup_workers")
      remote_resource.send_command_wakeup_workers
    end
    it "should send the command" do
      allow(RemoteCommand).to receive(:new)
      expect(remote_resource).to receive(:send_command)
      remote_resource.send_command_wakeup_workers
    end
  end
  describe "#send_command" do
    let(:command) {double(RemoteCommand, :is_a? => true).as_null_object}
    before(:each) do
      allow(remote_resource).to receive(:site)
      allow(Control).to receive(:new).and_return(double("control").as_null_object)
    end
    it "should raise an exception if command is not a RemoteCommand" do
      expect{remote_resource.send_command(nil)}.to raise_error(CbrainError)
    end
    it "should delegate to RemoteResource#process_command if called on model representing current app" do
      portal_resource = RemoteResource.current_resource
      expect(portal_resource.class).to receive(:process_command)
      portal_resource.send_command(command)
    end
    it "should send the command" do
      expect(Control).to receive(:new)
      remote_resource.send_command(command)
    end
    it "should return the command" do
      expect(remote_resource.send_command(command)).to be_instance_of(RemoteCommand)
    end
  end
  describe "#process_command" do
    let(:portal_resource) { RemoteResource.current_resource }
    before(:each) do
      allow(portal_resource).to receive(:auth_token).and_return("auth_token")
      allow(RemoteResource).to  receive(:current_resource).and_return(portal_resource)
      allow(Message).to         receive(:send_message)
    end
    it "should raise an exception if command not given" do
      command = double("command", :command => nil)
      expect{RemoteResource.process_command(command)}.to raise_error(CbrainError)
    end
    it "should send an error message if not given proper receiver token" do
      command = double("command", :command => "command", :receiver_token => "invalid").as_null_object
      expect(Message).to receive(:send_message)
      RemoteResource.process_command(command)
    end
    it "should send an error message if not given proper sender token" do
      command = double("command", :command => "command", :receiver_token => portal_resource.auth_token).as_null_object
      allow(RemoteResource).to receive(:valid_token?).and_return(false)
      expect(Message).to receive(:send_message)
      RemoteResource.process_command(command)
    end
    it "should call the proper process_command_xxx method" do
      command = double("command", :command => "command", :receiver_token => portal_resource.auth_token).as_null_object
      allow(RemoteResource).to receive(:valid_token?).and_return(true)
      expect(RemoteResource).to receive(:send).with(/^process_command_/, anything)
      RemoteResource.process_command(command)
    end
  end
  describe "#method_missing" do
    it "should raise a CbrainError if method has a 'process_command' prefix" do
      expect{RemoteResource.process_command_invalid}.to raise_error(CbrainError)
    end
    it "should raise a MethodMissing exception otherwise" do
      expect{RemoteResource.not_a_method}.to raise_error(NoMethodError)
    end
  end
end

