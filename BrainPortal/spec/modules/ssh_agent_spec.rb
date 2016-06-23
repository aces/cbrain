
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

describe SshAgent do

  describe ".find" do

    it "should call find_by_name if a name is given" do
      expect(SshAgent).to receive(:find_by_name).and_return 'OK'
      expect(SshAgent).not_to receive(:find_forwarded)
      expect(SshAgent).not_to receive(:find_current)
      expect(SshAgent.find("abcd")).to eq('OK')
    end

    it "should call find_forwarded if no name is given" do
      expect(SshAgent).not_to receive(:find_by_name)
      expect(SshAgent).to receive(:find_forwarded).and_return 'OK'
      expect(SshAgent).not_to receive(:find_current)
      expect(SshAgent.find()).to eq('OK')
    end

    it "should call find_current if find_forwarded returned nil" do
      expect(SshAgent).not_to receive(:find_by_name)
      expect(SshAgent).to receive(:find_forwarded).and_return nil
      expect(SshAgent).to receive(:find_current).and_return 'OK'
      expect(SshAgent.find()).to eq('OK')
    end

  end



  describe ".find_by_name" do

    it "should return nil if no such named agent exists" do
      allow(File).to receive(:file?).and_return false
      expect(SshAgent.find_by_name('abcd')).to be_nil
    end

    it "should return nil if the agent config is valid but the socket is dead" do
      allow(File).to receive(:file?).and_return true
      allow(File).to receive(:socket?).and_return false
      allow(File).to receive(:read).and_return "SSH_AUTH_SOCK=/tmp/abcd;SSH_AGENT_PID=1234"
      expect(SshAgent.find_by_name('abcd')).to be_nil
    end

    it "should return a named agent object if the named agent exists" do
      allow(File).to receive(:file?).and_return true
      allow(File).to receive(:socket?).and_return true
      allow(File).to receive(:read).and_return "SSH_AUTH_SOCK=/tmp/abcd;SSH_AGENT_PID=1234"
      agent = SshAgent.find_by_name('abcd')
      expect(agent).to be_instance_of(SshAgent)
      expect(agent.name).to   eq('abcd')
      expect(agent.pid).to    eq('1234')
      expect(agent.socket).to eq('/tmp/abcd')
    end

  end



  describe ".find_forwarded" do

    it "should attempt to find a named agent '_forwarded' if no SSH_AUTH_SOCK is set" do
      with_modified_env('SSH_AUTH_SOCK' => nil) do
        agent = SshAgent.new('_forwarded','/tmp/abcd/wrong/socket',nil)
        allow(agent).to receive(:write_agent_config_file)
        expect(SshAgent).to receive(:find_by_name).with('_forwarded').and_return agent
        expect(SshAgent.find_forwarded).to eq(agent)
      end
    end

    it "should attempt to find a named agent '_forwarded' if a SSH_AGENT_PID is set" do
      with_modified_env('SSH_AUTH_SOCK' => '/tmp/dummy_socket', 'SSH_AGENT_PID' => "12345") do
        agent = SshAgent.new('_forwarded','/tmp/abcd/wrong/socket',nil)
        allow(agent).to receive(:write_agent_config_file)
        expect(SshAgent).to receive(:find_by_name).with('_forwarded').and_return agent
        expect(SshAgent.find_forwarded).to eq(agent)
      end
    end

    it "should return a forwarded agent object if a forwarded agent exists" do
      with_modified_env('SSH_AUTH_SOCK' => '/tmp/dummy_socket', 'SSH_AGENT_PID' => nil) do
        allow(File).to receive(:socket?).and_return true
        expect(SshAgent).not_to receive(:find_by_name)
        allow(File).to receive(:open)
        agent = SshAgent.find_forwarded
        expect(agent).to be_instance_of(SshAgent)
        expect(agent.name).to eq('_forwarded')
      end
    end

  end



  describe ".find_current" do

    it "should return nil if no socket is detected" do
      with_modified_env('SSH_AUTH_SOCK' => nil, 'SSH_AGENT_PID' => nil) do
        expect(SshAgent.find_current).to be_nil
      end
    end

    it "should return an agent named '_current' if a socket is found" do
      with_modified_env('SSH_AUTH_SOCK' => "/tmp/some/socket", 'SSH_AGENT_PID' => "12345678") do
        allow(File).to receive(:socket?).and_return true
        agent = SshAgent.find_current
        expect(agent.name).to   eq('_current')
        expect(agent.socket).to eq('/tmp/some/socket')
        expect(agent.pid).to    eq('12345678')
      end
    end

    it "should never attempt to save a config file for the agent" do
      with_modified_env('SSH_AUTH_SOCK' => "/tmp/some/socket", 'SSH_AGENT_PID' => "12345678") do
        allow(File).to receive(:socket?).and_return true
        agent = SshAgent.new('_current', ENV['SSH_AUTH_SOCK'], ENV['SSH_AGENT_PID'])
        allow(SshAgent).to receive(:new).and_return agent
        expect(agent).not_to receive(:write_agent_config_file)
        agent = SshAgent.find_current
      end
    end

  end



  describe ".create" do

    it "should raise an exception if the named agent already exists" do
      allow(SshAgent).to receive_message_chain(:find_by_name,:try).and_return SshAgent.new('test')
      expect { SshAgent.create('test') }.to raise_error(RuntimeError)
    end

    context "when creating a new agent" do

      let!(:dummy_agent) { SshAgent.new('test') }

      before(:each) do
        expect(IO).to receive(:popen).and_return "SSH_AUTH_SOCK=/tmp/abcd\nSSH_AGENT_PID=1234\n"
        expect(SshAgent).to receive(:new).with('test', '/tmp/abcd', '1234').and_return dummy_agent
      end

      it "should create and return an agent object" do
        allow(dummy_agent).to receive(:write_agent_config_file)
        expect(SshAgent.create('test')).to eq(dummy_agent)
      end

      it "should create a config file for the agent" do
        expect(dummy_agent).to receive(:write_agent_config_file)
        expect(SshAgent.create('test')).to eq(dummy_agent)
      end

    end

  end



  describe ".find_or_create" do

    it "should try to find an existing agent" do
      expect(SshAgent).to receive(:find_by_name).with('abcd').and_return 'ok'
      expect(SshAgent).not_to receive(:create)
      expect(SshAgent.find_or_create('abcd')).to eq('ok')
    end

    it "should create a new one if no named agent exists" do
      expect(SshAgent).to receive(:find_by_name).with('abcd').and_return nil
      expect(SshAgent).to receive(:create).with('abcd').and_return 'ok'
      expect(SshAgent.find_or_create('abcd')).to eq('ok')
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
        expect(agent.apply).to be_truthy
        expect(ENV['SSH_AUTH_SOCK']).to eq('/tmp/abcd')
        expect(ENV['SSH_AGENT_PID']).to eq('1234')
      end
    end

    it "should invoke a given block in a changed environment" do
      agent = SshAgent.new('test','/tmp/abcd','1234')
      val = agent.apply do
        expect(ENV['SSH_AUTH_SOCK']).to eq('/tmp/abcd')
        expect(ENV['SSH_AGENT_PID']).to eq('1234')
        "invoked"
      end
      expect(val).to eq('invoked')
      expect(ENV['SSH_AUTH_SOCK']).to eq(saved_auth_sock)
      expect(ENV['SSH_AGENT_PID']).to eq(saved_agent_pid)
    end

  end



  describe "#is_alive?" do

    let!(:agent) { SshAgent.new('test','/tmp/abcd/wrong/socket','1234567') }

    it "should return false if socket path is invalid" do
      expect(IO).not_to receive(:popen)
      expect(agent.is_alive?).to be_falsey
    end

    it "should invoke ssh-add to check that the agent is alive" do
      allow(File).to receive(:socket?).and_return true
      expect(IO).to receive(:popen).and_return "OK"
      agent.is_alive?
    end

    it "should return false if ssh-add cannot connect" do
      allow(File).to receive(:socket?).and_return true
      allow(IO).to receive(:popen).and_return "Could not open a connection to your authentication agent."
      expect(agent.is_alive?).to be_falsey
    end

    it "should return true if ssh-add does connect to an agent with no identities" do
      allow(File).to receive(:socket?).and_return true
      allow(IO).to receive(:popen).and_return "The agent has no identities."
      expect(agent.is_alive?).to be_truthy
    end

    it "should return true if ssh-add does connect to an agent with some identities" do
      allow(File).to receive(:socket?).and_return true
      allow(IO).to receive(:popen).and_return "1024 9e:8a:9b:b5:33:4e:e5:b6:f1:e1:7a:82:47:de:d2:38 /Users/prioux/.ssh/id_dsa (DSA)"
      expect(agent.is_alive?).to be_truthy
    end

  end



  describe "#aliveness" do

    it "should return self if is_alive? is true" do
      agent = SshAgent.new('test','/tmp/abcd','12345678')
      expect(agent).to receive(:is_alive?).and_return true
      expect(agent.aliveness).to eq(agent)
    end

    it "should invoke destroy and return nil if is_alive? is false" do
      agent = SshAgent.new('test','/tmp/abcd','12345678')
      expect(agent).to receive(:is_alive?).and_return false
      expect(agent).to receive(:destroy).and_return true
      expect(agent.aliveness).to be_nil
    end

  end



  describe "#add_key_file" do

    let!(:agent) { SshAgent.new('test','/tmp/abcd/wrong/socket','1234567') }

    it "should raise an exception if the key file is invalid" do
      expect { agent.add_key_file('/tmp/does/not/exist') }.to raise_error(RuntimeError, /file doesn't exist/)
    end

    it "should return true if the identify was added" do
      allow(IO).to receive(:popen).and_return "Identity added: blah blah"
      expect(agent.add_key_file('/tmp/does/not/exist')).to be_truthy
    end

  end



  describe "#lock" do

    it "should invoke ssh-add -x" do
      expect(Kernel).to receive(:system).with("/bin/bash","-c",/ssh-add -x/).and_return true
      agent = SshAgent.new('whatever','/path/to/socket',nil)
      expect(agent.lock('mypassword')).to be_truthy
    end

  end



  describe "#unlock" do

    it "should invoke ssh-add -X" do
      expect(Kernel).to receive(:system).with("/bin/bash","-c",/ssh-add -X/).and_return true
      agent = SshAgent.new('whatever','/path/to/socket',nil)
      expect(agent.unlock('mypassword')).to be_truthy
    end

  end



  describe "#list_keys" do

    it "should raise an exception if ssh-add doesn't output a key" do
      expect(IO).to receive(:popen).with(/ssh-add/,anything()).and_return ""
      agent = SshAgent.new('whatever','/path/to/socket',nil)
      expect { agent.list_keys }.to raise_error(RuntimeError, /Agent doesn't seem to exist/)
    end

    it "should invoke ssh-add -l by default" do
      expect(IO).to receive(:popen).with(/ssh-add -l/,anything()).and_return "1024 9e:8a:9b:b5:33:4e:e5:b6:f1:e1:7a:82:47:de:d2:38 /Users/prioux/.ssh/id_dsa (DSA)"
      agent = SshAgent.new('whatever','/path/to/socket',nil)
      res = agent.list_keys
      expect(res).to be_instance_of(Array)
      expect(res.size).to eq(1)
    end

    it "should invoke ssh-add -L if options[:full] is true" do
      expect(IO).to receive(:popen).with(/ssh-add -L/,anything()).and_return "ssh-rsa abcdefabcdefabcdefabcdefacadefabcdefabcdef comment" # the code checks for at list 30 characters.
      agent = SshAgent.new('whatever','/path/to/socket',nil)
      res = agent.list_keys(:full => true)
      expect(res).to be_instance_of(Array)
      expect(res.size).to eq(1)
    end

  end



  describe "#destroy" do

    it "should kill the agent process if if it a named agent" do
      expect(Process).to receive(:kill).with('TERM',1234567).and_return nil
      allow(File).to receive(:unlink)
      agent = SshAgent.new('test','/tmp/abcd/wrong/socket','1234567')
      expect(agent.destroy).to be_truthy
    end

    it "should not kill the agent process if if it a forwarded agent" do
      expect(Process).not_to receive(:kill)
      allow(File).to receive(:unlink)
      agent = SshAgent.new('_forwarded','/tmp/abcd/wrong/socket',nil)
      expect(agent.destroy).to be_truthy
    end

    it "should not attempt to erase the agent's config file if it a forwarded agent" do
      expect(Process).not_to receive(:kill)
      expect(File).not_to receive(:unlink)
      agent = SshAgent.new('_forwarded','/tmp/abcd/wrong/socket',nil)
      expect(agent.destroy).to be_truthy
    end

    it "should not attempt to erase the agent's config file if it a 'current' agent" do
      allow(Process).to receive(:kill)
      expect(File).not_to receive(:unlink)
      agent = SshAgent.new('_current','/tmp/abcd/wrong/socket','123456')
      expect(agent.destroy).to be_truthy
    end

    it "should erase the agent config file, if any, if it is a named agent" do
      agent = SshAgent.new('test','/tmp/abcd/wrong/socket',nil)
      conf  = agent.agent_bash_config_file_path
      allow(Process).to receive(:kill)
      expect(File).to receive(:unlink).once.with(conf).and_return 1
      expect(File).to receive(:unlink).once.with(agent.socket).and_return 1
      expect(agent.destroy).to be_truthy
    end

  end



  describe "#agent_bash_config_file_path" do

    it "should return nil if the current agent is '_current'" do
      agent = SshAgent.new('_current','/tmp/path/to_socket','12345678')
      expect(agent.agent_bash_config_file_path).to be_nil
    end

    it "should invoke the class method with its name" do
      agent = SshAgent.new('test','/tmp/abcd/wrong/socket',nil)
      expect(SshAgent).to receive(:agent_config_file_path).with('test').and_return 'OK'
      expect(agent.agent_bash_config_file_path).to eq('OK')
    end

  end



  describe "#write_agent_config_file" do

    it "should raise an exception if the agent is '_current'" do
      agent = SshAgent.new('_current','/tmp/path/to_socket','12345678')
      expect { agent.write_agent_config_file }.to raise_error(RuntimeError, /Cannot write config/)
    end

    it "should write the config file" do
      agent = SshAgent.new('dummy','/tmp/path/to_socket','12345678')
      path  = agent.agent_bash_config_file_path
      fh    = double('filehandle')
      expect(File).to receive(:open).with(path, 'w').and_yield(fh)
      expect(fh).to receive(:write)
      agent.write_agent_config_file
    end

  end



  describe ".agent_config_file_path" do

    it "should raise an exception if name is not a simple identifier" do
      expect { SshAgent.send(:agent_config_file_path,'&') }.to raise_error(RuntimeError)
    end

    it "should build a path for 'abcd'" do
      expect(SshAgent.send(:agent_config_file_path,"abcd")).to be_instance_of(Pathname)
    end

  end



  describe ".read_agent_config_file" do

    it "should raise an exception if the file doesn't exist" do
      expect { SshAgent.send(:read_agent_config_file,'/tmp/a/b/c/d2121/e/f/g/h') }.to raise_error(Errno::ENOENT, /No such file/)
    end

    it "should invoke parse_agent_config_file" do
      test_content = "TestContent"
      allow(File).to receive(:read).and_return "TestContent"
      expect(SshAgent).to receive(:parse_agent_config_file).with(test_content)
      SshAgent.send(:read_agent_config_file, '/tmp/a/b/c/d2121/e/f/g/h')
    end

  end



  describe ".parse_agent_config_file" do

    it "should return a nil socket path if the file content doesn't have it" do
      content = "ZZZZZZZZZZZZZ=/tmp/abcd\nSSH_AGENT_PID=1234\n"
      s = SshAgent.send(:parse_agent_config_file, content).first
      expect(s).to be_nil
    end

    it "should return a null PID if the file content doesn't have it" do
      content = "SSH_AUTH_SOCK=/tmp/abcd\nZZZZZZZZZZZZZ=1234\n"
      p = SshAgent.send(:parse_agent_config_file, content).last
      expect(p).to be_nil
    end

    it "should return a socket path and PID if the content is OK" do
      content = "SSH_AUTH_SOCK=/tmp/abcd\nSSH_AGENT_PID=1234\n"
      s,p = SshAgent.send(:parse_agent_config_file, content)
      expect(s).to eq('/tmp/abcd')
      expect(p).to eq('1234')
    end

  end

end

