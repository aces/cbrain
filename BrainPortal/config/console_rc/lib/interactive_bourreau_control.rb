
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

# == Interactive Bourreau Control
#
# This class implements a simple command line interface to
# controlling the Bourreaux (starting and stopping them,
# and their workers too). It's mostly useful for sysadmins
# who need to quickly trigger these operations on many
# bourreaux en-masse, like during upgrades of large
# CBRAIN installations.
#
# The simplest use is to create an object for the
# interactive session then invoke the method for the
# command line interace:
#
#   ibc = InteactiveBourreauControl.new
#   ibc.interactive_control
# or
#
#   InteractiveBourreauControl.new.interactive_control
#
# The CBRAIN console initialization has a shortcut
# for all this simply called `ibc` .
class InteractiveBourreauControl

  # The interactive session handler is initialized with
  # a list of Bourreau to work on, and a terminal width.
  #
  # We maintain the state of the interactive session in a bunch of
  # instance variables.
  def initialize(bourreaux_list = Bourreau.order(:id).all, term_width = nil)
    @bourreaux = bourreaux_list
    @width     = term_width
    if term_width.blank? || term_width.to_i < 1
      numrows,numcols = Readline.get_screen_size rescue [25,120]
      @width           = numcols
    end
    @selected = {}
  end

  # Display the list of Bourreaux, highlighting
  # in green those that are online, in red thos that are offline,
  # and in reverse video those that the user has selected for
  # future commands.
  def show_bourreaux
    max_size = @bourreaux.map { |b| b.name.size }.max
    numcols  = @width / (max_size + 6)         # " 023=name "
    numcols  = 1 if numcols < 1
    numrows  = ((@bourreaux.size + 0.0) / numcols).ceil

    puts("=" * (@width-1))
    (0..(numrows-1)).each do |r|
      (0..(numcols-1)).each do |c|
        idx         = c+r*numcols
        next if idx >= @bourreaux.size
        bourreau    = @bourreaux[idx]
        color       = bourreau.online?         ? 2 : 1  # ANSI 1=red, 2=green, 4=blue
        reverse     = @selected[bourreau.id]   ? 7 : 0  # 7=reversevideo, 0=normal
        padded_name = sprintf("%-#{max_size}s",bourreau.name)
        col_name    = "\e[#{reverse};3#{color}m" + padded_name + "\e[0m"
        printf " %3d=%s ",
          bourreau.id,
          col_name
      end
      print "\n"
    end
    puts("=" * (@width-1))
  end

  # Interactive loop, asking command input from user.
  def interactive_control(initial_command = nil)
    @operations = ""
    @mode       = "each_bourreau"  # "Each Bourreau in turn run all commands"
                 #"each_operation" # "Each command in turn is run on all Bourreau"
    @got_stop   = false

    while (! @got_stop) do # I hate writing this

      #print "\e[H\e[J"
      show_bourreaux()
      print <<-OPERATIONS

Operations Queue: #{@operations.presence || "(None)"}
Operations Mode : #{@mode == "each_command" ?
    "Each command, in turn, executed to all selected bourreaux" :
    "Each selected bourreau, in turn, executes all commands"
  }

      OPERATIONS

      userinput     = initial_command.presence
      userinput   ||= Readline.readline("Do something (h for help): ",false)
      userinput     = "Q" if userinput.nil?
      inputkeywords = userinput.downcase.split(/\W+/).map(&:presence).compact

      dowait = false
      while (inputkeywords.size > 0)
        letter  = inputkeywords.shift # could be a number too
        dowait |= process_user_letter(letter)
      end
      puts ""
      if dowait && initial_command.blank?
        Readline.readline("Press RETURN to continue: ",false)
        puts ""
      end
      initial_command = nil
    end
    puts "Exiting.\n"
  end



  ###################################################################

  private

  # Parse the interactive command (usually, a single letter)
  def process_user_letter(letter) #:nodoc:

    # Validate the user input
    if letter !~ /^([haombwitukygsrczqx]|\d+|exit|quit)$/
      puts "Unknown command: #{letter} (ignored)"
      return false
    end

    # Help
    if letter == "h"
      print <<-Menu

    Toggle selection: [0-9]=by ID | A=all | O=online

    List of operations:

      * Start/Stop remote services (added to queue)

        B = starts bourreaux
        W = starts workers
        T = stops workers
        U = stops workers and waits to make sure
        K = stops bourreaux
        Y = cycle: stop workers and bourreaux then
            start bourreaux and workers (replace operation queue)

      * Queue Control

        Z = empties (zaps) operation queue
        G = executes operation queue
        M = toggles queue execution mode

      * Bash queries

        S = runs "ps" on the Bourreau side
        R = runs "ps" looking for workers only
        C = runs a BASH command on the Bourreau side

      * Misc

        I = query bourreaux for 'info' record
        E,Q,X = exits

      You can enter multiple commands all on a single line, e.g.
      to toggle Bourreaux #2, #12 then start their Bourreau and
      Workers one could enter:

         2 12 b w g

      Menu
      return false
    end

    # Quit
    if letter =~ /^[qex]$|^(exit|quit)$/
      @got_stop = true
      return false
    end

    # Toggle individual bourreau
    if letter =~ /^(\d+)$/
      to_toggle = letter.to_i
      @bourreaux.each { |b| @selected[b.id] = ! @selected[b.id] if b.id == to_toggle }
      return false
    end

    # Toggle all
    if letter == "a"
      @bourreaux.each { |b| @selected[b.id] = ! @selected[b.id] }
      return false
    end

    # Toggle all online
    if letter == "o"
      @bourreaux.each { |b| @selected[b.id] = ! @selected[b.id] if b.online? }
      return false
    end

    # Toggle mode
    if letter == "m"
      @mode = @mode == "each_bourreau" ? "each_command" : "each_bourreau"
      return false
    end

    # Cycle
    if letter == "y"
      @operations = "StopWorkersAndWait StopBourreaux StartBourreaux StartWorkers"
      return false
    end

    # Operation queue commands
    if letter =~ /^[bwtku]$/
      @operations += " " if @operations.present?
      @operations += "StartBourreaux"     if letter == "b"
      @operations += "StartWorkers"       if letter == "w"
      @operations += "StopBourreaux"      if letter == "k"
      @operations += "StopWorkers"        if letter == "t"
      @operations += "StopWorkersAndWait" if letter == "u"
      return false
    end

    # Zap operation queue
    if letter == "z"
      @operations = ""
      return false
    end

    # Execute operation queue
    if letter == "g"

      bourreau_list = @bourreaux.select { |b| @selected[b.id] }
      if bourreau_list.empty?
        puts "\nWell, no Bourreaux are selected. So nothing done."
        return false
      end

      op_list       = @operations.split(/\W+/).map(&:presence).compact
      if op_list.empty?
        puts "\nWell, no operations are queued. So nothing done."
        return false
      end

      puts "\n\nExecuting operation queue...\n"
      @operations=""

      if @mode == "each_command"
        op_list.each do |op|
          #puts "==== Command: #{op} ===="
          bourreau_list.each do |bou|
            res, mess = apply_operation(op, bou)
            # currently we don't do anything with res and mess
            #break if ! res
          end
        end
      end

      if @mode == "each_bourreau"
        bourreau_list.each do |bou|
          #puts "==== Bourreau: #{bou.name} ===="
          op_list.each do |op|
            res, mess = apply_operation(op, bou)
            # If stopping workers fail for any reason, we skip all other actions for this bourreau
            break if op =~ /StopWorkers/ && mess.present? && mess =~ /still active/i
          end
        end
      end
      return true
    end

    # Status: 'info'
    if letter == "i"
      bourreau_list = @bourreaux.select { |b| @selected[b.id] }
      if bourreau_list.empty?
        puts "\nWell, no Bourreaux are selected. So nothing done."
        return false
      end
      bourreau_list.each do |bou|
        puts "==== Bourreau: #{bou.name} ===="
        info = bou.remote_resource_info rescue { :exception => "Cannot connect." }
        info.keys.sort.each do |key|
          printf "%30s => %s\n",key.to_s,info[key].to_s
        end
      end
      return true
    end

    # Status: "ps"
    if letter == "s"
      bash_command_on_bourreaux(
        "ps -u $USER -o user,pid,%cpu,%mem,vsize,state,stime,time,command | sed -e 's/  *$//'"
      )
      return true
    end

    # Status: "ps" for workers
    if letter == "r"
      bash_command_on_bourreaux(
        "ps -u $USER -o user,pid,%cpu,%mem,vsize,state,stime,time,command | grep 'Worker @b@' | grep -v grep | sed -e 's/  *$//'"
      )
      return true
    end

    # Bash command
    if letter == "c"
      puts "Enter bash command; @b@ will be substituted by the Bourreaux names"
      comm = Readline.readline("Bash command: ")
      bash_command_on_bourreaux(comm)
      return true
    end

    # Internal error
    puts "Internal error: unknown command: #{letter}"
    @got_stop = true

  end

  def apply_operation(op, bou) #:nodoc:
    printf "... %18s %-15s : ", op, bou.name
    res,mess = [ false, "Unknown Operation #{op}" ]
    res,mess = start_bourreaux(bou)       if op == "StartBourreaux"
    res,mess = start_workers(bou)         if op == "StartWorkers"
    res,mess = stop_bourreaux(bou)        if op == "StopBourreaux"
    res,mess = stop_workers(bou)          if op == "StopWorkers"
    res,mess = stop_workers_and_wait(bou) if op == "StopWorkersAndWait"
    printf "%s\n", mess == nil ? "(nil)" : mess
    [ res, mess ]
  rescue IRB::Abort => ex
    puts "\b\bOperation interrupted by user"
    return [ false, "Interrupt" ]
  rescue => ex
    puts "Operation failed: #{ex.class}: #{ex.message}"
    return [ false, "Exception" ]
  end

  def stop_workers(b) #:nodoc:
    r=b.send_command_stop_workers rescue "(Exc)"
    r=r.command_execution_status if r.is_a?(RemoteCommand)
    [ r == 'OK' , r ]
  end

  def stop_workers_and_wait(b) #:nodoc:
    stop_ok, stop_mes = stop_workers(b)
    return [ stop_ok, stop_mes ] if ! stop_ok # if we didn't even get an OK from stop action
    # busy loop to wait for workers to stop
    output = []
    ntimes = 20 ; delay = 15  # total 5 minutes max
    ntimes.times do |i|
      mess = " (Wait #{i+1}/#{ntimes})"
      print mess + ( "\b" * mess.size )
      output = b.ssh_master.remote_shell_command_reader(
        "ps -u $USER -o pid,command | grep 'Worker #{b.name}' | grep -v grep"
      ) { |fh| fh.read.split(/\n/) }
      break if output.blank? # no lines mean all workers have exited
      delay.times { |d| print [ '-', '\\', '|', '/' ][d % 4], "\b" ; sleep 1 }
    end
    print " " * 30 + "\b" * 30
    [ output.blank? , output.blank? ? "OK" : "Workers still active" ] # message text used to abort sequence, see earlier in code
  end

  def stop_bourreaux(b) #:nodoc:
    r1=b.stop         rescue nil
    r2=b.stop_tunnels rescue nil
    b.update_attribute(:online, false)
    [ !!(r1 && r2) , "App: #{r1 or false}\tSSH Master: #{r2 or false}" ]
  end

  def start_bourreaux(b) #:nodoc:
    r   = b.start rescue nil
    rev = "???"
    if (r == true)
      rev = b.info(:ping).starttime_revision rescue nil
    end
    [ r == true, "App: #{r}\tRev: #{rev or "Exc"}" ]
  end

  def start_workers(b) #:nodoc:
    r=b.send_command_start_workers rescue "(Exc)"
    r=r.command_execution_status if r.is_a?(RemoteCommand)
    [ r == 'OK' , r ]
  end

  def bash_command_on_bourreaux(comm) #:nodoc:
    bourreau_list = @bourreaux.select { |b| @selected[b.id] }
    if bourreau_list.empty?
      puts "\nWell, no Bourreaux are selected. So nothing done."
      return
    end
    puts ""
    bourreau_list.each do |bou|
      puts "---- Bourreau: #{bou.name} ----"
      bash_command_on_one_bourreau(bou,comm.sub('@b@',bou.name))
    end
  end

  def bash_command_on_one_bourreau(b,comm) #:nodoc:
    if b.proxied_host.present? # another level of remote host... ?
      # ... then we prefix the remote command with another ssh call.
      comm = "ssh #{b.proxied_host.bash_escape} #{comm.bash_escape}"
    end
    b.ssh_master.remote_shell_command_reader(comm) # run it
  end

end

(CbrainConsoleFeatures ||= []) << <<FEATURES
========================================================
Feature: Interactive Bourreau Control
========================================================
  Activate with: ibc
FEATURES

