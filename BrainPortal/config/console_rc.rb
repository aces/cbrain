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

logger = Logger.new(STDOUT)
ActiveRecord::Base.logger = logger
ActiveResource::Base.logger = logger


# Custom prompt
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

Bourreau.first # does nothing but loads the class
class Bourreau
  def console
    start_remote_console
  end
  def self.console(id)
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

# Run command on each Bourreau
def bb_bash(*bb)

  ActiveRecord::Base.logger.level=Logger::ERROR rescue true
  ActiveResource::Base.logger.level=Logger::ERROR rescue true

  if ! block_given?
    puts <<-USAGE

Usage: bb_bash(bourreau_list = <online bourreaux>) { |b| "bash_command" }
    USAGE
    return false
  end

  bb = bb[0] if bb.size == 1 && bb[0].is_a?(Array)
  bb = Bourreau.find_all_by_online(true) if bb.blank?
  bb = bb.map do |b|
    if b.is_a?(String)
      Bourreau.find_by_name(b)
    elsif (b.is_a?(Fixnum) || b.to_s =~ /^\d+$/)
      Bourreau.find_by_id(b)
    else
      b
    end
  end
  unless bb.all? { |b| b.is_a?(Bourreau) }
    puts "Not all Bourreaux."
    return false
  end

  bb.each do |b|
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

  true

ensure
  ActiveRecord::Base.logger.level=Logger::DEBUG
  ActiveResource::Base.logger.level=Logger::DEBUG
end


# Utility for mass restarts of bourreaux
def cycle_bb(*bb)

  ActiveRecord::Base.logger.level=Logger::ERROR rescue true
  ActiveResource::Base.logger.level=Logger::ERROR rescue true

  what = bb.shift

  if what.blank?
    puts <<-USAGE

Usage: cycle_bb(what, bourreau_list = <online bourreaux>)
where 'what' is "start", "stop", "workon", "workoff" or a combination,
or the keyword "all" which means "stop start workon".

    USAGE
    return false
  end

  bb = bb[0] if bb.size == 1 && bb[0].is_a?(Array)
  bb = Bourreau.find_all_by_online(true) if bb.blank?
  bb = bb.map do |b|
    if b.is_a?(String)
      Bourreau.find_by_name(b)
    elsif (b.is_a?(Fixnum) || b.to_s =~ /^\d+$/)
      Bourreau.find_by_id(b)
    else
      b
    end
  end
  unless bb.all? { |b| b.is_a?(Bourreau) }
    puts "Not all Bourreaux."
    return false
  end

  started = {}
  what = "stop start workon" if what =~ /all/



  if what =~ /workoff|stop/

    puts "\nStopping Workers..."

    bb.each do |b|
      printf "... %15s : ", b.name
      r=b.send_command_stop_workers rescue "(Exc)"
      r=r.command_execution_status if r.is_a?(RemoteCommand)
      puts   r.to_s
    end

  end



  if what =~ /stop/

    puts "\nStopping Bourreaux..."

    bb.each do |b|
      printf "... %15s : ", b.name
      r1=b.stop         rescue "(Exc)"
      r2=b.stop_tunnels rescue "(Exc)"
      puts   "App: #{r1.to_s}    SSH Master: #{r2.to_s}"
      b.update_attribute(:online, false)
    end

  end



  if what =~ /start/

    puts "\nStarting Bourreaux..."

    bb.each do |b|
      printf "... %15s : ", b.name
      r=b.start rescue "(Exc)"
      rev = (r == true) ? b.info(:ping).starttime_revision : "???"
      puts   "#{r.to_s}\tRev: #{rev}"
      started[b]=true if r == true
    end

  end



  if what =~ /workon/

    puts "\nStarting Workers..."
    sleep 4

    bb.each do |b|
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
  ActiveRecord::Base.logger.level=Logger::DEBUG
  ActiveResource::Base.logger.level=Logger::DEBUG
end

# Show bourreau worker processes on given bourreau(x).
def ps_work(*arg)
  bb_bash(*arg){ |b| "ps ax -o euser,pid,%cpu,%mem,vsize,state,stime,time,command | grep 'BourreauWorker #{b.name}' | grep -v grep | sed -e 's/  *$//'" }
end

# Show all processes on given bourreau(x).
def ps_bb(*arg)
  bb_bash(*arg){ |b| "ps ax -o euser,pid,%cpu,%mem,vsize,state,stime,time,command | grep ^$USER | sed -e 's/  *$//'" }
end


begin
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
end


# Load external IRBRC file
IRB.rc_file_generators do |rcgen|
  rc_file_path = rcgen.call("rc")
  if File.exist?(rc_file_path)
    load rc_file_path
    break
  end
end

