
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
    #sleep 4
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

# Utility method used by bb_bash() etc
def resolve_bourreaux(bb)
  bb = bb[0] if bb.size == 1 && bb[0].is_a?(Array)
  bb = no_log { Bourreau.find_all_by_online(true) } if bb.blank?
  bourreau_list = bb.map do |b|
    if b.is_a?(String)
      no_log { Bourreau.find_by_name(b) }
    elsif (b.is_a?(Fixnum) || b.to_s =~ /\A\d+\z/)
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

