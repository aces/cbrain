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
  no_log()

  # Run command on each
  bourreau_list.each do |b|
    puts "================ #{b.name} ================"
    comm = yield(b)
    if ! comm.is_a?(String)
      puts "Block returned no string: #{comm.inspect}"
    else
      if b.proxied_host.present?
        comm = "ssh #{b.proxied_host.bash_escape} #{comm.bash_escape}"
      end
      b.ssh_master.remote_shell_command_reader(comm)
    end
  end
  return true
ensure
  do_log()
end


# Utility for mass control of bourreaux
#
# cycle_bb :start,   [list of bourreaux]   # starts bourreaux
# cycle_bb :stop,    [list of bourreaux]   # stops bourreaux (implies :workoff)
# cycle_bb :workon,  [list of bourreaux]   # starts bourreau workers
# cycle_bb :workoff, [list of bourreaux]   # starts bourreau workers
# cycle_bb :cycle,   [list of bourreaux]   # does 'workoff,stop,start,workon'
def cycle_bb(*bb)

  what = bb.shift

  if what.blank?
    puts <<-USAGE

Usage: cycle_bb(what, bourreau_list = <online bourreaux>)
where 'what' is "start", "stop", "workon", "workoff" or a combination,
or the keyword "cycle" which means "stop start workon".

    USAGE
    return false
  end

  # Find list of target bourreaux
  bourreau_list = resolve_bourreaux(bb)
  return false if bourreau_list.blank?

  # Prevents AR logging while we work here
  no_log()
  bourreau_list = resolve_bourreaux(bb)

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
  do_log()
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
def no_log
  ActiveRecord::Base.logger.level   = Logger::ERROR rescue true
  ActiveResource::Base.logger.level = Logger::ERROR rescue true
end

# Enable AR logging
def do_log
  ActiveRecord::Base.logger.level   = Logger::DEBUG
  ActiveResource::Base.logger.level = Logger::DEBUG
end

# Utility method used by bb_bash() etc
def resolve_bourreaux(bb)
  bb = bb[0] if bb.size == 1 && bb[0].is_a?(Array)
  bb = Bourreau.find_all_by_online(true) if bb.blank?
  bourreau_list = bb.map do |b|
    if b.is_a?(String)
      Bourreau.find_by_name(b)
    elsif (b.is_a?(Fixnum) || b.to_s =~ /^\d+$/)
      Bourreau.find_by_id(b)
    elsif b.is_a?(Regexp)
      Bourreau.all.detect { |x| x.name =~ b }
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
def self.cu(user=:show)
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
def self.cp(group='show me')
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



#####################################################
# Preload single table inheritance models
#####################################################

begin
  no_log()
  Dir.chdir(File.join(Rails.root.to_s, "app", "models")) do
    Dir.glob("*.rb").each do |model|
      model.sub!(/.rb$/,"")
      require_dependency "#{model}.rb" unless Object.const_defined? model.classify
    end
  end

  #Load userfile file types
  Dir.chdir(File.join(Rails.root.to_s, "app", "models", "userfiles")) do
    Dir.glob("*.rb").each do |model|
      model.sub!(/.rb$/,"")
      require_dependency "#{model}.rb" unless Object.const_defined? model.classify
    end
  end
rescue => error
  if error.to_s.match(/Mysql::Error.*Table.*doesn't exist/i)
    puts "Skipping model load:\n\t- Database table doesn't exist yet. It's likely this system is new and the migrations have not been run yet."
  elsif error.to_s.match(/Unknown database/i)
    puts "Skipping model load:\n\t- System database doesn't exist yet. It's likely this system is new and the migrations have not been run yet."
  else
    raise
  end
ensure
  do_log()
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

