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

# Rails console initialization code.
puts "C> CBRAIN Rails Console Initalization starting"

# Create a new logger for ActiveRecord operations
console_logger              = Logger.new(STDOUT)
ActiveRecord::Base.logger   = console_logger
ActiveResource::Base.logger = console_logger

# Custom prompt: insert the name of the CBRAIN RemoteResource (portal or Bourreau)
rr_name = RemoteResource.current_resource.name rescue "Rails Console"
IRB.conf[:PROMPT][:CUSTOM] = {
  :PROMPT_I => "#{rr_name} :%03n > ",
  :PROMPT_S => "#{rr_name} :%03n%l> ",
  :PROMPT_C => "#{rr_name} :%03n > ",
  :PROMPT_N => "#{rr_name} :%03n?> ",
  :RETURN   => " => %s \n",
  :AUTO_INDENT => true
}
IRB.conf[:PROMPT_MODE] = :CUSTOM



# Adds two wrapper commands to connect to the Rails Console
# of remote Bourreaux:
#
# bourreau.console  # connects to the console of object 'bourreau'
# Bourreau.console(id_or_name_or_regex) # finds a bourreau and connects
Bourreau.nil? # does nothing but loads the class
class Bourreau

  def console #:nodoc:
    start_remote_console
  end

  def self.console(id) #:nodoc:
    b   = self.find(id)         rescue nil
    b ||= self.find_by_name(id) rescue nil
    b ||= self.all.detect { |x| x.name =~ id } if id.is_a?(Regexp)
    unless b
      puts "Can't find a Bourreau that match '#{id.inspect}'"
      return
    end
    puts "Starting console for Bourreau '#{b.name}'"
    b.console
  end
end



#####################################################
# Bourreau Control Methods
#####################################################

# Run a bash command on each Bourreau
# The bash command must be a string returned by the block
# The list of bourreau can be provided as ids, as names,
# or as bourreau objects themselves.
#
# Example:
#
#   bb_bash(23, /super/) { |b| "echo On #{b.name} hostname is `hostname`" }
#
# will run the bash command on Bourreaux #23 and the ones with names matching /super/.
def bb_bash(*bb)

  if ! block_given?
    puts <<-USAGE

Usage: bb_bash(bourreau_list = <online bourreaux>) { |b| "bash_command" }
    USAGE
    return false
  end

  # Find list of target bourreaux
  bourreau_list = resolve_bourreaux(bb)
  return false if bourreau_list.blank?

  # Prevents AR logging while we work here
  no_log do

    # Run command on each
    bourreau_list.each do |b|
      puts "================ #{b.name} ================"
      comm = yield(b) # the bash command to run on the remote host
      if ! comm.is_a?(String)
        puts "Block didn't return a string to use as command. Got: #{comm.inspect}"
        next
      end
      # ok send command to remote host
      if b.proxied_host.present? # another level of remote host... ?
        # ... then we prefix the remote command with another ssh call.
        comm = "ssh #{b.proxied_host.bash_escape} #{comm.bash_escape}"
      end
      b.ssh_master.remote_shell_command_reader(comm) # run it
    end
    return true

  end

end


# Utility for mass control of bourreaux
#
# cycle_bb :start,   [list of bourreaux]   # starts bourreaux
# cycle_bb :stop,    [list of bourreaux]   # stops bourreaux (implies :workoff)
# cycle_bb :workon,  [list of bourreaux]   # starts bourreau workers
# cycle_bb :workoff, [list of bourreaux]   # stops bourreau workers
# cycle_bb :cycle,   [list of bourreaux]   # does 'workoff,stop,start,workon'
def cycle_bb(*bb)

  what = bb.shift

  if what.blank?
    puts <<-USAGE

Usage: cycle_bb(what, bourreau_list = <online bourreaux>)
where 'what' is "start", "stop", "workon", "workoff" or a combination,
or the keyword "cycle" which means "workoff stop start workon".

    USAGE
    return false
  end

  # Find list of target bourreaux
  bourreau_list = resolve_bourreaux(bb)
  return false if bourreau_list.blank?

  # Disable all logging; undone in ensure block a tend of method (uglee)
  no_log

  # Figure out what to do
  started = {}
  what = "stop start workon" if what =~ /all|cycle/

  # WORKERS STOP
  if what =~ /workoff|stop/
    puts "\nStopping Workers..."
    bourreau_list.each do |b|
      printf "... %15s : ", b.name
      r=b.send_command_stop_workers rescue "(Exc)"
      r=r.command_execution_status if r.is_a?(RemoteCommand)
      puts   r.to_s
    end
  end

  # BOURREAUX STOP
  if what =~ /stop/
    puts "\nStopping Bourreaux..."
    bourreau_list.each do |b|
      printf "... %15s : ", b.name
      r1=b.stop         rescue "(Exc)"
      r2=b.stop_tunnels rescue "(Exc)"
      puts   "App: #{r1.to_s}    SSH Master: #{r2.to_s}"
      b.update_attribute(:online, false)
    end
  end

  # BOURREAUX START
  if what =~ /start/
    puts "\nStarting Bourreaux..."
    bourreau_list.each do |b|
      printf "... %15s : ", b.name
      r=b.start rescue "(Exc)"
      rev = (r == true) ? b.info(:ping).starttime_revision : "???"
      puts   "#{r.to_s}\tRev: #{rev}"
      started[b]=true if r == true
    end
  end

  # WORKERS START (why am I shouting?)
  if what =~ /workon/
    puts "\nStarting Workers..."
    sleep 4
    bourreau_list.each do |b|
      printf "... %15s : ", b.name
      if (what =~ /all|start/ && started[b]) || what =~ /work/
        r=b.send_command_start_workers rescue "(Exc)"
        r=r.command_execution_status if r.is_a?(RemoteCommand)
      else
        r="(Skipped)"
      end
      puts   r.to_s
    end
  end

  puts ""
  true
ensure
  do_log
end

# Show bourreau worker processes on given bourreau(x).
def ps_work(*arg)
  bb_bash(*arg){ |b| "ps -u $USER -o user,pid,%cpu,%mem,vsize,state,stime,time,command | grep 'Worker #{b.name}' | grep -v grep | sed -e 's/  *$//'" }
end

# Show all processes on given bourreau(x).
def ps_bb(*arg)
  bb_bash(*arg){ |b| "ps -u $USER -o user,pid,%cpu,%mem,vsize,state,stime,time,command | sed -e 's/  *$//'" }
end

# Disable AR logging (actually, just sets logging level to ERROR)
def no_log(&block)
  set_log_level(Logger::ERROR,&block) rescue nil
end

# Enable AR logging
def do_log(&block)
  set_log_level(Logger::DEBUG,&block) rescue nil
end

def set_log_level(level) #:nodoc:
  l1 = ActiveRecord::Base.logger.level   rescue nil
  l2 = ActiveResource::Base.logger.level rescue nil
  ActiveRecord::Base.logger.level   = level rescue true
  ActiveResource::Base.logger.level = level rescue true
  if block_given?
    begin
      return yield
    ensure
      ActiveRecord::Base.logger.level   = l1 if l1
      ActiveResource::Base.logger.level = l2 if l2
    end
  end
end

# Utility method used by bb_bash() etc
def resolve_bourreaux(bb)
  bb = bb[0] if bb.size == 1 && bb[0].is_a?(Array)
  bb = no_log { Bourreau.find_all_by_online(true) } if bb.blank?
  bourreau_list = bb.map do |b|
    if b.is_a?(String)
      no_log { Bourreau.find_by_name(b) }
    elsif (b.is_a?(Fixnum) || b.to_s =~ /^\d+$/)
      no_log { Bourreau.find_by_id(b) }
    elsif b.is_a?(Regexp)
      no_log { Bourreau.all.detect { |x| x.name =~ b } }
    else
      b
    end
  end
  unless bourreau_list.all? { |b| b.is_a?(Bourreau) }
    puts "Not all Bourreaux."
    return nil
  end
  bourreau_list.uniq
end

# Reconnects to the database
def recon
  ActiveRecord::Base.verify_active_connections!
  ActiveRecord::Base.connected?
end



#####################################################
# Current User / Current Project Utility Methods
#####################################################

def current_user #:nodoc:
  $_current_user
end

def current_project #:nodoc:
  $_current_project
end

# Sets the current user. Invoke on the
# console's command line with:
#
#   cu 'name'
#   cu id
#   cu /regex/
def cu(user=:show)
  return $_current_user if user == :show
  if user.nil? || user.is_a?(User)
    $_current_user = user
  elsif user.is_a?(Fixnum) || (user.is_a?(String) && user =~ /^\d+$/)
    $_current_user = User.find(user)
  elsif user.is_a?(String)
    $_current_user = User.where([ "(login like ?) OR (full_name like ?)", "%#{user}%", "%#{user}%" ]).first
  elsif user.is_a?(Regexp)
    $_current_user = User.all.detect { |u| (u.login =~ user) || (u.full_name =~ user) }
  else
    raise "Need a ID, User object, regex, or a string."
  end
  puts "Current user is now: #{$_current_user.try(:login) || "(nil)"}"
end

# Sets the current project. Invoke on the
# console's command line with:
#
#   cp 'name'
#   cp id
#   cp /regex/
def cp(group='show me')
  return $_current_project if group == 'show me'
  if group.nil? || group.is_a?(Group)
    $_current_project = group
  elsif group.is_a?(Fixnum) || (group.is_a?(String) && group =~ /^\d+$/)
    $_current_project = Group.find(group)
  elsif group.is_a?(Regexp)
    $_current_project = Group.all.detect { |g| g.name =~ group }
  elsif group.is_a?(String)
    $_current_project = Group.where([ "name like ?", "%#{group}%" ]).first
  else
    raise "Need a ID, Group object, regex or a string."
  end
  puts "Current project is now: #{$_current_project.try(:name) || "(nil)"}"
end

cu User.admin
cp nil

# Friendly Fast Finder
# Search for anything by ID or name.
# Sets variables in the console with the objects found:
#
#   @ff # array of Userfile objects
#   @tt # array of CbrainTask objects
#   @uu # array of User objects
#   @gg # array of Group objects
#   @rr # array of RemoteResource objects
#   @dd # array of DataProvider objects
#   @ss # array of Site objects
#   @oo # array of Tool objects
#   @cc # array of ToolConfig objects
#
# At the same time, if any of these arrays contain any entries
# a similar variable with a single letter name (e.g. @u, @t, @g etc) will
# be set to the first entry of the array.
#
# A special subject of @rr containing only objects of subclass Bourreau will
# be in @bb (with the similar @b also set).
def fff(token)

  results=no_log { ModelsReport.search_for_token(token,cu) }
  @ff = results[:files  ]; @f = @ff[0]
  @tt = results[:tasks  ]; @t = @tt[0]
  @uu = results[:users  ]; @u = @uu[0]
  @gg = results[:groups ]; @g = @gg[0]
  @rr = results[:rrs    ]; @r = @rr[0]
  @dd = results[:dps    ]; @d = @dd[0]
  @ss = results[:sites  ]; @s = @ss[0]
  @oo = results[:tools  ]; @o = @oo[0]
  @cc = results[:tcs    ]; @c = @cc[0]
  @bb = @rr.select { |r| r.is_a?(Bourreau) }; @b = @bb[0]

  report = lambda do |name,letter|  # ("User", 'u') will look into @uu and @u
    list = eval "@#{letter}#{letter}" # look up @uu or @ff etc
    next if list.size == 0
    if (list.size == 1)
      first = list[0]
      pretty = first.respond_to?(:to_summary) ? no_log { first.to_summary } : first.inspect[0..60]
      printf "%15s : @#{letter} = %s\n",name,pretty
    else
      printf "%15s : @#{letter}#{letter} contains %d results\n",
        ApplicationController.helpers.pluralize("2",name).sub(/^[\s\d]+/,""), # ugleeee
        list.size
    end
  end

  report.("File",           'f')
  report.("Task",           't')
  report.("User",           'u')
  report.("Group",          'g')
  report.("DataProvider",   'd')
  report.("RemoteResource", 'r')
  report.("Site",           's')
  report.("Tool",           'o')
  report.("ToolConfig",     'c')
  report.("Bourreau",       'b')

end



#####################################################
# Add 'to_summary' methods to the objects that can
# be found by 'fff', for pretty reports.
#####################################################

# Make sure the classes are loaded
# Note that it's important ot load PortalTask too, because of its own pre-loading of subclasses.
[ Userfile, CbrainTask, PortalTask, User, Group, DataProvider, RemoteResource, Site, Tool, ToolConfig, Bourreau ]


class Userfile
  def to_summary
    sprintf "<%s#%d> [%s:%s] S=%s N=\"%s\" DP=%s",
      self.class.to_s, self.id,
      user.login,      group.name,
      size ? size : "unk",
      name,            data_provider.name
  end
end

class CbrainTask
  def to_summary
    sprintf "<%s#%d> [%s:%s] S=%s B=%s",
      self.class.to_s, self.id,
      user.login,      group.name,
      cluster_workdir_size.presence || "unk",
      bourreau.name
  end
end

class User
  def to_summary
    sprintf "<%s#%d> L=%s F=\"%s\" S=%s",
      self.class.to_s, self.id,
      login,      full_name,
      site.try(:name) || "(No site)"
  end
end

class Group
  def to_summary
    sprintf "<%s#%d> N=\"%s\" C=%s",
      self.class.to_s, self.id,
      name,
      creator.try(:login) || "(No creator)"
  end
end

class DataProvider
  def to_summary
    sprintf "<%s#%d> [%s:%s] N=\"%s\"",
      self.class.to_s, self.id,
      user.login,      group.name,
      name
  end
end

class RemoteResource
  def to_summary
    sprintf "<%s#%d> [%s:%s] N=\"%s\"",
      self.class.to_s, self.id,
      user.login,      group.name,
      name
  end
end

class Site
  def to_summary
    sprintf "<%s#%d> N=\"%s\"",
      self.class.to_s, self.id,
      name
  end
end

class Tool
  def to_summary
    sprintf "<%s#%d> [%s:%s] N=\"%s\" C=%s",
      self.class.to_s, self.id,
      user.login,      group.name,
      name,
      cbrain_task_class
  end
end

class ToolConfig
  def to_summary
    sprintf "<%s#%d> [%s] T=%s B=%s V=\"%s\"",
      self.class.to_s, self.id,
      group.name,
      try(:tool).try(:name)     || "(No tool)",
      try(:bourreau).try(:name) || "(No bourreau)",
      version_name.presence     || "(No version)"
  end
end



#####################################################
# Load external IRBRC file
#####################################################

IRB.rc_file_generators do |rcgen|
  rc_file_path = rcgen.call("rc")
  if File.exist?(rc_file_path)
    load rc_file_path
    break
  end
end

