
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

describe SshAgent do

  describe ".find" do

    it "should call find_by_name if a name is given" do
      SshAgent.should_receive(:find_by_name).and_return 'OK'
      SshAgent.should_not_receive(:find_forwarded)
      SshAgent.should_not_receive(:find_current)
      SshAgent.find("abcd").should == 'OK'
    end

    it "should call find_forwarded if no name is given" do
      SshAgent.should_not_receive(:find_by_name)
      SshAgent.should_receive(:find_forwarded).and_return 'OK'
      SshAgent.should_not_receive(:find_current)
      SshAgent.find().should == 'OK'
    end

    it "should call find_current if find_forwarded returned nil" do
      SshAgent.should_not_receive(:find_by_name)
      SshAgent.should_receive(:find_forwarded).and_return nil
      SshAgent.should_receive(:find_current).and_return 'OK'
      SshAgent.find().should == 'OK'
    end

  end



  describe ".find_by_name" do

    it "should return nil if no such named agent exists" do
      File.stub!(:file?).and_return false
      SshAgent.find_by_name('abcd').should be_nil
    end

    it "should return nil if the agent config is valid but the socket is dead" do
      File.stub!(:file?).and_return true
      File.stub!(:socket?).and_return false
      File.stub!(:read).and_return "SSH_AUTH_SOCK=/tmp/abcd;SSH_AGENT_PID=1234"
      SshAgent.find_by_name('abcd').should be_nil
    end

    it "should return a named agent object if the named agent exists" do
      File.stub!(:file?).and_return true
      File.stub!(:socket?).and_return true
      File.stub!(:read).and_return "SSH_AUTH_SOCK=/tmp/abcd;SSH_AGENT_PID=1234"
      agent = SshAgent.find_by_name('abcd')
      agent.should be_instance_of(SshAgent)
      agent.name.should   == 'abcd'
      agent.pid.should    == '1234'
      agent.socket.should == '/tmp/abcd'
    end

  end



  describe ".find_forwarded" do

    it "should attempt to find a named agent '_forwarded' if no SSH_AUTH_SOCK is set" do
      with_modified_env('SSH_AUTH_SOCK' => nil) do
        agent = SshAgent.new('_forwarded','/tmp/abcd/wrong/socket',nil)
        agent.stub!(:write_agent_config_file)
        SshAgent.should_receive(:find_by_name).with('_forwarded').and_return agent
        SshAgent.find_forwarded.should == agent
      end
    end

    it "should attempt to find a named agent '_forwarded' if a SSH_AGENT_PID is set" do
      with_modified_env('SSH_AUTH_SOCK' => '/tmp/dummy_socket', 'SSH_AGENT_PID' => "12345") do
        agent = SshAgent.new('_forwarded','/tmp/abcd/wrong/socket',nil)
        agent.stub!(:write_agent_config_file)
        SshAgent.should_receive(:find_by_name).with('_forwarded').and_return agent
        SshAgent.find_forwarded.should == agent
      end
    end

    it "should return a forwarded agent object if a forwarded agent exists" do
      with_modified_env('SSH_AUTH_SOCK' => '/tmp/dummy_socket', 'SSH_AGENT_PID' => nil) do
        File.stub!(:socket?).and_return true
        SshAgent.should_not_receive(:find_by_name)
        File.stub!(:open)
        agent = SshAgent.find_forwarded
        agent.should be_instance_of(SshAgent)
        agent.name.should == '_forwarded'
      end
    end

  end



  describe ".find_current" do

    it "should return nil if no socket is detected" do
      with_modified_env('SSH_AUTH_SOCK' => nil, 'SSH_AGENT_PID' => nil) do
        SshAgent.find_current.should be_nil
      end
    end

    it "should return an agent named '_current' if a socket is found" do
      with_modified_env('SSH_AUTH_SOCK' => "/tmp/some/socket", 'SSH_AGENT_PID' => "12345678") do
        File.stub!(:socket?).and_return true
        agent = SshAgent.find_current
        agent.name.should   == '_current'
        agent.socket.should == '/tmp/some/socket'
        agent.pid.should    == '12345678'
      end
    end

    it "should never attempt to save a config file for the agent" do
      with_modified_env('SSH_AUTH_SOCK' => "/tmp/some/socket", 'SSH_AGENT_PID' => "12345678") do
        File.stub!(:socket?).and_return true
        agent = SshAgent.new('_current', ENV['SSH_AUTH_SOCK'], ENV['SSH_AGENT_PID'])
        SshAgent.stub(:new).and_return agent
        agent.should_not_receive(:write_agent_config_file)
        agent = SshAgent.find_current
      end
    end

  end



  describe ".create" do

    it "should raise an exception if the named agent already exists" do
      SshAgent.stub_chain(:find_by_name,:try).and_return SshAgent.new('test')
      lambda { SshAgent.create('test') }.should raise_error(RuntimeError)
    end

    context "when creating a new agent" do

      let!(:dummy_agent) { SshAgent.new('test') }

      before(:each) do
        IO.should_receive(:popen).and_return "SSH_AUTH_SOCK=/tmp/abcd\nSSH_AGENT_PID=1234\n"
        SshAgent.should_receive(:new).with('test', '/tmp/abcd', '1234').and_return dummy_agent
      end

      it "should create and return an agent object" do
        dummy_agent.stub!(:write_agent_config_file)
        SshAgent.create('test').should == dummy_agent
      end

      it "should create a config file for the agent" do
        dummy_agent.should_receive(:write_agent_config_file)
        SshAgent.create('test').should == dummy_agent
      end

    end

  end



  describe ".find_or_create" do

    it "should try to find an existing agent" do
      SshAgent.should_receive(:find_by_name).with('abcd').and_return 'ok'
      SshAgent.should_not_receive(:create)
      SshAgent.find_or_create('abcd').should == 'ok'
    end

    it "should create a new one if no named agent exists" do
      SshAgent.should_receive(:find_by_name).with('abcd').and_return nil
      SshAgent.should_receive(:create).with('abcd').and_return 'ok'
      SshAgent.find_or_create('abcd').should == 'ok'
    end

  end



  describe "#apply" do

   let!(:saved_auth_sock) { ENV['SSH_AUTH_SOCK'] }
   let!(:saved_agent_pid) { ENV['SSH_AGENT_PID'] }

   after(:each) do
     ENV['SSH_AUTH_SOCK'] = saved_auth_sock
     ENV['SSH_AGENT_PID'] = saved_agent_pid
   end

    it "should change the environment's SSH_AUTH_SOCK and SSH_AGENT_PID" do
      agent = SshAgent.new('test','/tmp/abcd','1234')
      with_modified_env('SSH_AUTH_SOCK' => nil, 'SSH_AGENT_PID' => nil) do
        agent.apply.should be_true
        ENV['SSH_AUTH_SOCK'].should == '/tmp/abcd'
        ENV['SSH_AGENT_PID'].should == '1234'
      end
    end

    it "should invoke a given block in a changed environment" do
      agent = SshAgent.new('test','/tmp/abcd','1234')
      val = agent.apply do
        ENV['SSH_AUTH_SOCK'].should == '/tmp/abcd'
        ENV['SSH_AGENT_PID'].should == '1234'
        "invoked"
      end
      val.should == 'invoked'
      ENV['SSH_AUTH_SOCK'].should == saved_auth_sock
      ENV['SSH_AGENT_PID'].should == saved_agent_pid
    end

  end



  describe "#is_alive?" do

    let!(:agent) { SshAgent.new('test','/tmp/abcd/wrong/socket','1234567') }

    it "should return false if socket path is invalid" do
      IO.should_not_receive(:popen)
      agent.is_alive?.should be_false
    end

    it "should invoke ssh-add to check that the agent is alive" do
      File.stub!(:socket?).and_return true
      IO.should_receive(:popen).and_return "OK"
      agent.is_alive?
    end

    it "should return false if ssh-add cannot connect" do
      File.stub!(:socket?).and_return true
      IO.stub!(:popen).and_return "Could not open a connection to your authentication agent."
      agent.is_alive?.should be_false
    end

    it "should return true if ssh-add does connect to an agent with no identities" do
      File.stub!(:socket?).and_return true
      IO.stub!(:popen).and_return "The agent has no identities."
      agent.is_alive?.should be_true
    end

    it "should return true if ssh-add does connect to an agent with some identities" do
      File.stub!(:socket?).and_return true
      IO.stub!(:popen).and_return "1024 9e:8a:9b:b5:33:4e:e5:b6:f1:e1:7a:82:47:de:d2:38 /Users/prioux/.ssh/id_dsa (DSA)"
      agent.is_alive?.should be_true
    end

  end



  describe "#aliveness" do

    it "should return self if is_alive? is true" do
      agent = SshAgent.new('test','/tmp/abcd','12345678')
      agent.should_receive(:is_alive?).and_return true
      agent.aliveness.should == agent
    end

    it "should invoke destroy and return nil if is_alive? is false" do
      agent = SshAgent.new('test','/tmp/abcd','12345678')
      agent.should_receive(:is_alive?).and_return false
      agent.should_receive(:destroy).and_return true
      agent.aliveness.should be_nil
    end

  end



  describe "#add_key_file" do

    let!(:agent) { SshAgent.new('test','/tmp/abcd/wrong/socket','1234567') }

    it "should raise an exception if the key file is invalid" do
      lambda { agent.add_key_file('/tmp/does/not/exist') }.should raise_error
    end

    it "should return true if the identify was added" do
      IO.stub!(:popen).and_return "Identity added: blah blah"
      agent.add_key_file('/tmp/does/not/exist').should be_true
    end

  end



  describe "#lock" do

    it "should invoke ssh-add -x" do
      Kernel.should_receive(:system).with("/bin/bash","-c",/ssh-add -x/).and_return true
      agent = SshAgent.new('whatever','/path/to/socket',nil)
      agent.lock('mypassword').should be_true
    end

  end



  describe "#unlock" do

    it "should invoke ssh-add -X" do
      Kernel.should_receive(:system).with("/bin/bash","-c",/ssh-add -X/).and_return true
      agent = SshAgent.new('whatever','/path/to/socket',nil)
      agent.unlock('mypassword').should be_true
    end

  end



  describe "#list_keys" do

    it "should raise an exception if ssh-add doesn't output a key" do
      IO.should_receive(:popen).with(/ssh-add/,anything()).and_return ""
      agent = SshAgent.new('whatever','/path/to/socket',nil)
      lambda { agent.list_keys }.should raise_error
    end

    it "should invoke ssh-add -l by default" do
      IO.should_receive(:popen).with(/ssh-add -l/,anything()).and_return "1024 9e:8a:9b:b5:33:4e:e5:b6:f1:e1:7a:82:47:de:d2:38 /Users/prioux/.ssh/id_dsa (DSA)"
      agent = SshAgent.new('whatever','/path/to/socket',nil)
      res = agent.list_keys
      res.should be_instance_of(Array)
      res.size.should == 1
    end

    it "should invoke ssh-add -L if options[:full] is true" do
      IO.should_receive(:popen).with(/ssh-add -L/,anything()).and_return "ssh-rsa abcdefabcdefabcdefabcdefacadefabcdefabcdef comment" # the code checks for at list 30 characters.
      agent = SshAgent.new('whatever','/path/to/socket',nil)
      res = agent.list_keys(:full => true)
      res.should be_instance_of(Array)
      res.size.should == 1
    end

  end



  describe "#destroy" do

    it "should kill the agent process if if it a named agent" do
      Process.should_receive(:kill).with('TERM',1234567).and_return nil
      File.stub!(:unlink)
      agent = SshAgent.new('test','/tmp/abcd/wrong/socket','1234567')
      agent.destroy.should be_true
    end

    it "should not kill the agent process if if it a forwarded agent" do
      Process.should_not_receive(:kill)
      File.stub!(:unlink)
      agent = SshAgent.new('_forwarded','/tmp/abcd/wrong/socket',nil)
      agent.destroy.should be_true
    end

    it "should not attempt to erase the agent's config file if it a forwarded agent" do
      Process.should_not_receive(:kill)
      File.should_not_receive(:unlink)
      agent = SshAgent.new('_forwarded','/tmp/abcd/wrong/socket',nil)
      agent.destroy.should be_true
    end

    it "should not attempt to erase the agent's config file if it a 'current' agent" do
      Process.stub!(:kill)
      File.should_not_receive(:unlink)
      agent = SshAgent.new('_current','/tmp/abcd/wrong/socket','123456')
      agent.destroy.should be_true
    end

    it "should erase the agent config file, if any, if it is a named agent" do
      agent = SshAgent.new('test','/tmp/abcd/wrong/socket',nil)
      conf  = agent.agent_bash_config_file_path
      Process.stub!(:kill)
      File.should_receive(:unlink).once.with(conf).and_return 1
      File.should_receive(:unlink).once.with(agent.socket).and_return 1
      agent.destroy.should be_true
    end

  end



  describe "#agent_bash_config_file_path" do

    it "should return nil if the current agent is '_current'" do
      agent = SshAgent.new('_current','/tmp/path/to_socket','12345678')
      agent.agent_bash_config_file_path.should be_nil
    end

    it "should invoke the class method with its name" do
      agent = SshAgent.new('test','/tmp/abcd/wrong/socket',nil)
      SshAgent.should_receive(:agent_config_file_path).with('test').and_return 'OK'
      agent.agent_bash_config_file_path.should == 'OK'
    end

  end



  describe "#write_agent_config_file" do

    it "should raise an exception if the agent is '_current'" do
      agent = SshAgent.new('_current','/tmp/path/to_socket','12345678')
      lambda { agent.write_agent_config_file }.should raise_error
    end

    it "should write the config file" do
      agent = SshAgent.new('dummy','/tmp/path/to_socket','12345678')
      path  = agent.agent_bash_config_file_path
      fh    = mock('filehandle')
      File.should_receive(:open).with(path, 'w').and_yield(fh)
      fh.should_receive(:write)
      agent.write_agent_config_file
    end

  end



  describe ".agent_config_file_path" do

    it "should raise an exception if name is not a simple identifier" do
      lambda { SshAgent.send(:agent_config_file_path,'&') }.should raise_error(RuntimeError)
    end

    it "should build a path for 'abcd'" do
      SshAgent.send(:agent_config_file_path,"abcd").should be_instance_of(Pathname)
    end

  end



  describe ".read_agent_config_file" do

    it "should raise an exception if the file doesn't exist" do
      lambda { SshAgent.send(:read_agent_config_file,'/tmp/a/b/c/d2121/e/f/g/h') }.should raise_error
    end

    it "should invoke parse_agent_config_file" do
      test_content = "TestContent"
      File.stub!(:read).and_return "TestContent"
      SshAgent.should_receive(:parse_agent_config_file).with(test_content)
      SshAgent.send(:read_agent_config_file, '/tmp/a/b/c/d2121/e/f/g/h')
    end

  end



  describe ".parse_agent_config_file" do

    it "should return a nil socket path if the file content doesn't have it" do
      content = "ZZZZZZZZZZZZZ=/tmp/abcd\nSSH_AGENT_PID=1234\n"
      s,p = SshAgent.send(:parse_agent_config_file, content)
      s.should be_nil
    end

    it "should return a null PID if the file content doesn't have it" do
      content = "SSH_AUTH_SOCK=/tmp/abcd\nZZZZZZZZZZZZZ=1234\n"
      s,p = SshAgent.send(:parse_agent_config_file, content)
      p.should be_nil
    end

    it "should return a socket path and PID if the content is OK" do
      content = "SSH_AUTH_SOCK=/tmp/abcd\nSSH_AGENT_PID=1234\n"
      s,p = SshAgent.send(:parse_agent_config_file, content)
      s.should == '/tmp/abcd'
      p.should == '1234'
    end

  end

end

