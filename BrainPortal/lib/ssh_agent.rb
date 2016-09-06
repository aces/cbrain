
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

# This class provides the functionality necessary to create,
# destroy and manage persistent SSH agents.
#
# Original author: Pierre Rioux

require 'fcntl'
require 'rubygems'
require 'sys/proctable'
require 'active_support'

# This class manages a set of ssh-agent processes, mostly by
# encapsulating the two variables that allows the 'ssh-add'
# command to connect to them: SSH_AUTH_SOCK and SSH_AGENT_PID.
#
# Each ssh-agent process is given a simple identifier as a name.
# They are persistent accross multiple Ruby processes, and even
# when the Ruby processes exit. These are called 'named agents'
# and their parameters (the values of the environment variables)
# are stored in small files in BASH format.
#
# The class is also capable of detecting and recording
# a single forwarded agent.
#
# == Creating an agent
#
# This will spawn a new ssh-agent process and store its
# connection information under the name 'myname'.
#
#   agent = SshAgent.create('myname')
#
# Once created, a config file containing the environment variables
# that represent this agent will be created. The path of
# this file can be obtained with agent_bash_config_file_path().
#
# == Finding an existing agent
#
# This will return an agent previously created by create(),
# even by another Ruby process.
#
#   agent = SshAgent.find_by_name('myname')
#
# == Finding a forwarded agent
#
# If a SSH connection provided the current process with
# a forwarding socket for a remote agent, then this method
# will find it:
#
#   agent = SshAgent.find_forwarded
#
# Once found, such an agent can then again be obtained with
# the name '_forwarded' using the find_by_name() method.
# Just like for the method create(), a config file can also
# be obtained with agent_bash_config_file_path().
#
# == Finding the current agent
#
# This creates an object representing the current ssh-agent,
# whether it is a locally running process or a forwarded
# one. Its name will be '_current' and no config file for
# it can be created.
#
#   agent = SshAgent.find_current
#
class SshAgent

  #include Sys  # for ProcTable  TODO

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Class configuration.
  CONFIG = { #:nodoc:
    :agent_bashrc_dir => (Rails.root rescue nil) ? "#{Rails.root.to_s}/tmp" : "/tmp",
    :hostname         => Socket.gethostname,
    :exec_askpass     => (Rails.root rescue nil) ?  "#{Rails.root.to_s}/vendor/cbrain/bin/askpass.sh" : "/bin/true",
    :exec_ssh_agent   => `which ssh-agent`.strip,
    :exec_ssh_add     => `which ssh-add`.strip,
  }

  # A name for the agent; there are two special names,
  # '_forwarded' and '_current', to represent a
  # agent forwarded by a SSH connection, and the
  # currently active agent (no matter what it is).
  attr_reader :name

  # PID of the agent process; this is nil if the agent
  # is forwarded.
  attr_reader :pid

  # Path to socket to connect to the agent.
  attr_reader :socket

  def initialize(name,socket=nil,pid=nil) #:nodoc:
    raise "Invalid name" unless name =~ /\A[a-z]\w*\z/i || name == '_forwarded' || name == '_current'
    @name   = name
    @socket = socket.present? ? socket.to_s : nil
    @pid    = pid.present?    ? pid.to_s    : nil
  end


  #----------------------------
  # Finder methods, class level
  #----------------------------

  # With a +name+, does a find_by_name(name).
  # If no +name+ is given, attempts a find_forwarded()
  # followed by a find_current() as a backup.
  def self.find(name=nil)
    name.present? ? self.find_by_name(name) : (self.find_forwarded || self.find_current)
  end

  # Finds a previously created named agent called +name+.
  # The info about the agent is read back from a config
  # file, and so it is possible that the agent is no longer
  # existing.
  def self.find_by_name(name)
    conf_file    = agent_config_file_path(name)
    return nil unless File.file?(conf_file)
    socket,pid   = read_agent_config_file(conf_file)
    return nil unless socket.present? && File.socket?(socket)
    self.new(name,socket,pid)
  end

  # Checks the current environment to see if it corresponds
  # to a state where a forwarded agent is available; if so
  # it will return an agent object to represent it and store
  # its info in a config file just like if it had been
  # created with the name '_forwarded'.
  def self.find_forwarded
    socket = ENV['SSH_AUTH_SOCK'].presence
    return self.find_by_name('_forwarded') unless socket && File.socket?(socket)
    agent_pid = ENV['SSH_AGENT_PID'].presence
    return self.find_by_name('_forwarded') if agent_pid # there is no ssh-agent process if it's forwarded
    agent = self.new('_forwarded', socket, nil)
    agent.write_agent_config_file
    agent
  end

  # Checks the current environment and returns an agent
  # object representing whatever ssh-agent seems to be
  # active. (this can be a forwarded connection or
  # a standalone active process, and thus can correspond
  # to the same agent returned by find_by_name() or
  # find_forwarded().
  def self.find_current
    socket = ENV['SSH_AUTH_SOCK'].presence
    return nil unless socket && File.socket?(socket)
    agent_pid = ENV['SSH_AGENT_PID'].presence
    agent = self.new('_current', socket, agent_pid)
    agent
  end

  # Creates a new SshAgent object representing a launched
  # ssh-agent process, associated with the +name+. If a
  # process already seems to exists, raise an exception.
  def self.create(name, socketpath=nil)
    exists = self.find_by_name(name).try(:aliveness)
    raise "Agent named '#{name}' already exists." if exists
    raise "Socket or file '#{socketpath}' already exists." if socketpath.present? && File.exists?(socketpath)
    dash_a     = socketpath.present? ? "-a #{socketpath.bash_escape}" : ""
    agent_out  = IO.popen("#{CONFIG[:exec_ssh_agent]} -s #{dash_a}","r") { |fh| fh.read }
    socket,pid = parse_agent_config_file(agent_out)
    agent      = self.new(name, socket, pid)
    agent.write_agent_config_file
    agent
  end

  # This attempts to find_by_name(), and if this fails it
  # invokes create().
  def self.find_or_create(name)
    self.find_by_name(name) || self.create(name)
  end



  #-----------------------
  # Agent instance methods
  #-----------------------

  # When invoked with no block given, sets the environment in
  # the current Ruby process so that SSH_AUTH_SOCK and SSH_AGENT_PID
  # corresponds to the agent. Returns true.
  #
  # When invoked with a block, temporarily change the environment
  # with these two variables and runs the block in the changed
  # environment. Returns what the block returns.
  def apply
    if block_given?
      return with_modified_env('SSH_AUTH_SOCK' => self.socket, 'SSH_AGENT_PID' => self.pid) { yield }
    end
    ENV['SSH_AUTH_SOCK'] = self.socket.present? ? self.socket.to_s : nil
    ENV['SSH_AGENT_PID'] = self.pid.present?    ? self.pid.to_s    : nil
    true
  end

  # Checks that the agent is alive and responding.
  def is_alive?
    return false unless self.socket.present? && File.socket?(self.socket)
    with_modified_env('SSH_AUTH_SOCK' => self.socket) do
      out = IO.popen("#{CONFIG[:exec_ssh_add]} -l 2>&1","r") { |fh| fh.read }
      # "1024 9e:8a:9b:b5:33:4e:e5:b6:f1:e1:7a:82:47:de:d2:38 /Users/prioux/.ssh/id_dsa (DSA)"
      # "Could not open a connection to your authentication agent."
      # "The agent has no identities."
      return false if     out =~ /could not open/i
      return true  if     out =~ /agent has no identities/i
      return false unless out =~ /:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:/
      true
    end
  end

  # Does a is_alive?() check; if it succeeds, returns the agent;
  # otherwise does a destroy() and returns nil. Can be used just
  # after a find:
  #
  #   agent = SshAgent.find_by_name('abcd').try(:aliveness)
  #   agent = SshAgent.find_forwarded.try(:aliveness)
  #
  def aliveness
    return self if self.is_alive?
    self.destroy rescue nil
    nil
  end

  # Adds a private key stored in file +keypath+ in the agent.
  # Raises an exception if the 'ssh-add' command complains.
  def add_key_file(keypath = "#{ENV['HOME']}/.ssh/id_rsa")
    out = IO.popen("#{CONFIG[:exec_ssh_add]} #{keypath.to_s.bash_escape} 2>&1","r") { |fh| fh.read }
    raise "Key file doesn't exist, is invalid, or has improper permission" unless out =~ /\AIdentity added/i
    true
  end

  # Stops the agent, removes the socket file, remove
  # the agent's config file.
  def destroy
    if self.pid.present?
      Process.kill('TERM',self.pid.to_i) rescue nil
      ENV['SSH_AGENT_PID'] = nil if ENV['SSH_AGENT_PID'] == self.pid
      @pid = nil
    end
    if self.name.present? && self.name != '_forwarded' && self.name != '_current'
      File.unlink(self.agent_bash_config_file_path)
      @name = '_destroyed_'
      ENV['SSH_AUTH_SOCK'] = nil if ENV['SSH_AUTH_SOCK'] == self.socket
      File.unlink(self.socket) rescue nil
      @socket = nil
    end
    true
  end

  # Lock the agent with a passphrase.
  def lock(password)
    lock_or_unlock(password,'x') # ssh-add option -x to lock
  end

  # Unlock the agent with a passphrase.
  def unlock(password)
    lock_or_unlock(password,'X') # ssh-add option -X to lock
  end

  # Returns an array of public keys in the agent; by
  # default each entry is a line as produced by 'ssh-add -l'.
  # If options[:full] is true, the entries correspond to 'ssh-add -L'.
  def list_keys(options = {})
    l_or_L = options[:full].present? ? 'L' : 'l'
    with_modified_env('SSH_AUTH_SOCK' => self.socket) do
      out = IO.popen("#{CONFIG[:exec_ssh_add]} -#{l_or_L} 2>&1","r") { |fh| fh.read }
      # -l "1024 9e:8a:9b:b5:33:4e:e5:b6:f1:e1:7a:82:47:de:d2:38 /Users/prioux/.ssh/id_dsa (DSA)"
      # -L "ssh-rsa AAAAB3NzaC1yc2E...aXdHJXq6+rmPGRAlQQWQTRSHw== /Users/prioux/.ssh/id_cbrain_portal"
      #    "Could not open a connection to your authentication agent."
      #    "The agent has no identities."
      return [] if out =~ /agent has no identities/i
      raise "Agent doesn't seem to exist anymore." if
       (l_or_L == 'l' && out !~ /:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:/) ||
       (l_or_L == 'L' && out !~ /\Assh-\S+\s+[a-zA-Z0-9\+\/]{30}/) # base 64 include let, dig, +, /
      return out.split(/\r?\n/)
    end
  end



  #---------------------
  # Config file methods
  #---------------------

  # Returns a path to a BASH script containing the
  # settings for the ssh-agent process (or the
  # forwarded agent).
  def agent_bash_config_file_path
    return nil if self.name == '_current'
    self.class.agent_config_file_path(self.name)
  end

  def write_agent_config_file #:nodoc:
    umask = File.umask(0077)
    raise "Cannot write config file for the 'current' agent!" if self.name == '_current'
    filename = self.class.agent_config_file_path(self.name)
    File.open(filename,"w") do |fh|
      fh.write(<<-AGENT_CONF)
# File created automatically by SshAgent rev. #{self.revision_info.format()}
# This script is in bash format and corresponds more or less to
# the output of the 'ssh-agent -s' command.
# This agent is named '#{self.name}'.
SSH_AUTH_SOCK=#{self.socket}; export SSH_AUTH_SOCK;
SSH_AGENT_PID=#{self.pid}; export SSH_AGENT_PID;
echo Agent pid #{self.pid};
      AGENT_CONF
    end
  ensure
    File.umask(umask) rescue true
  end

  def self.agent_config_file_path(name) #:nodoc:
    raise "Agent name is not a simple identifier." unless name.present? && (name =~ /\A[a-z]\w*\z/i || name == '_forwarded')
    Pathname.new(CONFIG[:agent_bashrc_dir]) + "#{name}@#{CONFIG[:hostname]}.agent.bashrc"
  end



  private

  def lock_or_unlock(password, mode) #:nodoc:
    with_modified_env('SSH_AUTH_SOCK'         => self.socket,
                      'SSH_ASKPASS'           => CONFIG[:exec_askpass],
                      'DISPLAY'               => 'none:0.0', # dummy, but needs to be set
                      'CBRAIN_PASSPHRASE'     => password.to_s.tr("'\"","")
                 ) do
      ret = Kernel.system("/bin/bash","-c","#{CONFIG[:exec_ssh_add]} -#{mode} </dev/null >/dev/null 2>/dev/null")
      return ret
    end
  end

  def self.read_agent_config_file(filename) #:nodoc:
    content = File.read(filename)
    parse_agent_config_file(content)
  end

  def self.parse_agent_config_file(content) #:nodoc:
    sockpath = (content =~ /SSH_AUTH_SOCK=([^;\s]+)/) && Regexp.last_match[1]
    agentpid = (content =~ /SSH_AGENT_PID=([^;\s]+)/) && Regexp.last_match[1]
    return sockpath, agentpid
  end

end
