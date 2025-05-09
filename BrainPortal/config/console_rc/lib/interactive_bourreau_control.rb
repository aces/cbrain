
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

require 'readline'
require 'reline'   # Readline.get_screen_size fails me

# We need some sort of constant to refer to the console's
# context, which has access to all the pretty helpers etc.
ConsoleCtx = self # also in pretty_view.rb in the same directory

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
# command line interface:
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
    @myself     = RemoteResource.current_resource # normally, in the console, a BrainPortal
    @bourreaux  = bourreaux_list.to_a
    @bourreaux |= [ @myself ] # add the current BrainPortal
    @bourreaux.sort!   { |x,y| x.id <=> y.id }
    @bourreaux.reject! { |b| b.meta[:ibc_hide] }
    @width      = term_width
    if term_width.blank? || term_width.to_i < 1
      _,numcols = Reline.get_screen_size rescue [25,120]
      @width          = numcols
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
        name        = bourreau.name
        color       = bourreau.online?         ? 2 : 1  # ANSI 1=red, 2=green, 4=blue
        reverse     = @selected[bourreau.id]   ? 7 : 0  # 7=reversevideo, 0=normal
        is_port     = @bourreaux[idx].is_a?(BrainPortal) ? ";4" : ""  # underline
        padding     = " " * (max_size - name.size)
        col_name    = "\e[#{reverse};3#{color}#{is_port}m" + name + "\e[0m" + padding
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
      show_bourreaux()    if initial_command.blank?
      print <<-OPERATIONS if initial_command.blank?

Operations Queue: #{@operations.presence || "(None)"}
Operations Mode : #{
        @mode == "each_command" ?
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
      puts "" if initial_command.nil?
      if dowait && initial_command.blank?
        Readline.readline("Press RETURN to continue: ",false)
        puts ""
      end
      initial_command &&= ""  # nil means no command ever provided; "" means a command was provided
    end
    puts "Exiting.\n" if initial_command.nil?
    true
  end



  ###################################################################

  private

  # Parse the interactive command (usually, a single letter)
  def process_user_letter(letter) #:nodoc:

    # Validate the user input
    if letter !~ /^([haombwiptukygsrczqxjfdn]|\d+|exit|quit)$/
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
        K = stops bourreaux (using shell commands)

        W = starts task workers
        T = stops task workers
        U = stops task workers and waits to make sure

        F = starts BAC workers
        D = stops BAC workers
        N = stops BAC workers and waits to make sure

        J = stops all workers and bourreaux (using command control
            messages; use this only if you're sure no workers
            are active and the SSH masters are opened)

        Y = cycle: stop task workers, BAC workers and bourreaux
            then restarts them all (replace operation queue)
            Synonym to "U N K B W". Note that starting a Bourreau
            also starts its BAC workers.

      * Queue Control

        Z = empties (zaps) operation queue
        G = executes operation queue
        M = toggles queue execution mode

      * Bash queries

        S = runs "ps" on the Bourreau side
        R = runs "ps" looking for workers and Bourreaux only
        C = runs a BASH command on the Bourreau side

      * Misc

        I = query bourreaux for 'info' record
        P = ping bourreaux (just uptime and number of workers)
        E,Q,X = exits

      You can enter multiple commands all on a single line, e.g.
      to toggle Bourreaux #2, #12 then start their Bourreau and
      Workers one could enter:

         2 12 b w g

      * About The Portal

      Among the list of Bourreau, a single entry for the current
      Portal will also be added. None of the commands to start or
      stop bourreaux and task workers work for the BrainPortal.
      Only BACWorkers operations are allowed. Also, the commands
      don't actually contact any running BrainPortal servers, it
      connects to the console's own process itself instead. That
      means the information returned by 'info' and 'ping' is just
      information about the console.

      * Hiding Bourreaux

      You can hide any of the bourreaux by adding a meta data
      entry 'ibc_hide' to them, e.g. in the console:

          Bourreau.find(342).meta[:ibc_hide] = true

      and they won't show up in the 'ibc' session.
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
      @operations = "StopWorkersAndWait StopBACWorkersAndWait StopBourreaux StartBourreaux StartWorkers"
      return false
    end

    # Operation queue commands
    if letter =~ /^[bwtkujfdn]$/
      @operations += " " if @operations.present?
      @operations += "StartBourreaux"     if letter == "b"
      @operations += "StopBourreaux"      if letter == "k"
      @operations += "StartWorkers"       if letter == "w"
      @operations += "StopWorkers"        if letter == "t"
      @operations += "StopWorkersAndWait" if letter == "u"
      @operations += "StartBACWorkers"    if letter == "f"
      @operations += "StopBACWorkers"     if letter == "d"
      @operations += "StopBACWorkersAndWait" if letter == "n"
      @operations += "StopAllByCommand"   if letter == "j"
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
        puts "\n\e[33mWell, no Bourreaux are selected. So nothing done.\e[0m"
        return false
      end

      op_list       = @operations.split(/\W+/).map(&:presence).compact
      if op_list.empty?
        puts "\n\e[33mWell, no operations are queued. So nothing done.\e[0m"
        return false
      end

      if bourreau_list.any? { |b| b.is_a?(BrainPortal) } && op_list.any? { |x| x !~ /BACWorker/i }
        puts "\n\e[31mIf the BrainPortal is selected, only BACWorker operations are allowed.\e[0m"
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
            res.nil? ; mess.nil? # just to silence a warning with ruby -c
          end
        end
      end

      if @mode == "each_bourreau"
        bourreau_list.each do |bou|
          #puts "==== Bourreau: #{bou.name} ===="
          op_list.each do |op|
            res, mess = apply_operation(op, bou)
            res.nil? # just to silence a warning with ruby -c
            # If stopping workers fail for any reason, we skip all other actions for this bourreau
            break if op =~ /Stop.*Workers/ && mess.present? && mess =~ /still active/i
          end
        end
      end
      return true
    end

    # Status: 'info'
    if letter == "i" || letter == "p"
      bourreau_list = @bourreaux.select { |b| @selected[b.id] }
      if bourreau_list.empty?
        puts "\nWell, no Bourreaux are selected. So nothing done."
        return false
      end
      max_size = bourreau_list.map { |b| b.name.size }.max
      bourreau_list.each do |bou|
        puts "==== Bourreau: #{bou.name} ====" if letter == "i"
        info = bou.remote_resource_info(letter == "i" ? :info : :ping) rescue { :exception => "Cannot connect." }
        if letter == "i"
          info.keys.sort.each do |key|
            printf "%30s => %s\n",key.to_s,info[key].to_s
          end
        else
          uptime     = info[:uptime];      uptime     = nil if uptime     == '???'
          gitrev     = info[:starttime_revision]
          numworkers = info[:worker_pids]; numworkers = nil if numworkers == '???'
          numworkers = (numworkers || "").split(",").count
          numBACw    = info[:bac_worker_pids]; numBACw = nil if numBACw   == '???'
          numBACw    = (numBACw    || "").split(",").count
          expworkers = bou.workers_instances || 0
          expBACw    = bou.activity_workers_instances || 0
          uptime     = uptime.to_i if uptime;
          uptime   &&= ConsoleCtx.send(:pretty_elapsed, uptime, :num_components => 2, :short => true)
          uptime   &&= "up for #{uptime}"
          uptime   ||= "DOWN"
          acttasks   = bou.cbrain_tasks.active.count rescue 0
          acttasks   = nil if acttasks == 0
          acttasks &&= " \e[36m(#{acttasks} active tasks)\e[0m" # CYAN
          rubtasks   = bou.cbrain_tasks.status(:ruby).count rescue 0
          rubtasks   = nil if rubtasks == 0
          rubtasks &&= " \e[35m(#{rubtasks} in Ruby stages)\e[0m" # MAGENTA
          bactasks   = bou.background_activities.where(:status => 'InProgress').count
          bactasks   = nil if bactasks == 0
          bactasks &&= " \e[34m(#{bactasks} active BACs)\e[0m" # BLUE
          procbacs   = bou.background_activities.locked.count
          procbacs   = nil if procbacs == 0
          procbacs &&= " \e[33m(#{procbacs} processing BACs)\e[0m" # YELLOW
          color_on   = color_off = nil
          color_on   = "\e[31m" if uptime == 'DOWN'          # RED    for down bourreaux
          color_on ||= "\e[33m" if numworkers != expworkers || numBACw != expBACw  # YELLOW for missing workers
          color_on ||= "\e[32m"                              # GREEN  when everything ok
          color_off  = "\e[0m"  if color_on
          if bou.is_a?(Bourreau)
            printf "#{color_on}%#{max_size}s rev %-9.9s %s, %d/%d workers, %d/%d BAC workers#{color_off}#{acttasks}#{rubtasks}#{bactasks}#{procbacs}\n", bou.name, gitrev, uptime, numworkers, expworkers, numBACw, expBACw
          else
            printf "#{color_on}%#{max_size}s rev %-9.9s %s, %d/%d BAC workers#{color_off}#{bactasks}#{procbacs}\n", bou.name, gitrev, uptime, numBACw, expBACw
          end
        end
      end
      return true
    end

    # Status: "ps"
    if letter == "s"
      bash_command_on_bourreaux(
        #"ps -u $USER -o user,pid,%cpu,%mem,vsize,state,stime,time,command | sed -e 's/  *$//'"
        "ps xww -o pid,vsz,lstart,time,args | grep -v grep | sed -e 's/  *$//'"
      )
      return true
    end

    # Status: "ps" for workers and Bourreaux
    if letter == "r"
      bash_command_on_bourreaux(
        #"ps -u $USER -o user,pid,%cpu,%mem,vsize,state,stime,time,command | egrep 'Worker @b@|Bourreau @b@' | grep -v grep | sed -e 's/  *$//'"
        "ps xww -o pid,vsz,lstart,time,args | egrep 'COMMAND|Worker @b@|Bourreau @b@' | grep -v grep | sed -e 's/  *$//'"
      )
      return true
    end

    # Bash command
    if letter == "c"
      puts "Enter bash command; some substitutions will be performed before"
      puts "sending the command:"
      puts " * @b@ will be substituted by the local Bourreau name"
      puts " * @r@ will be substituted by the Bourreau's RAILS root path"
      puts " * @d@ will be substituted by the Bourreau's DP cache dir path"
      puts " * @g@ will be substituted by the Bourreau's gridshare dir path"
      comm = Readline.readline("Bash command: ")
      bash_command_on_bourreaux(comm)
      return true
    end

    # Internal error
    puts "Internal error: unknown command: #{letter}"
    @got_stop = true

  end

  def apply_operation(op, bou) #:nodoc:
    printf "... %21s %-15s : ", op, bou.name
    res,mess = [ false, "Unknown Operation #{op}" ]
    res,mess = start_bourreau(bou)        if op == "StartBourreaux"
    res,mess = start_workers(bou)         if op == "StartWorkers"
    res,mess = stop_bourreau(bou)         if op == "StopBourreaux"
    res,mess = stop_workers(bou)          if op == "StopWorkers"
    res,mess = stop_workers_and_wait(bou) if op == "StopWorkersAndWait"
    res,mess = stop_all_by_command(bou)   if op == "StopAllByCommand"
    res,mess = start_bac_workers(bou)     if op == "StartBACWorkers"
    res,mess = stop_bac_workers(bou)      if op == "StopBACWorkers"
    res,mess = stop_bac_workers_and_wait(bou) if op == "StopBACWorkersAndWait"
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
      output = bash_command_on_one_bourreau(b,
        "ps -u $USER -o pid,command | grep 'Worker #{b.name}' | grep -v grep"
      ) { |fh| fh.read.split(/\n/) }
      break if output.blank? # no lines mean all workers have exited
      delay.times { |d| print [ '-', '\\', '|', '/' ][d % 4], "\b" ; sleep 1 }
    end
    print " " * 30 + "\b" * 30
    [ output.blank? , output.blank? ? "OK" : "Workers still active" ] # message text used to abort sequence, see earlier in code
  end

  def start_bac_workers(b)
    r=b.send_command_start_bac_workers rescue "(Exc)"
    r=r.command_execution_status if r.is_a?(RemoteCommand)
    [ r == 'OK', r ]
  end

  def stop_bac_workers(b)
    r=b.send_command_stop_bac_workers rescue "(Exc)"
    r=r.command_execution_status if r.is_a?(RemoteCommand)
    [ r == 'OK', r ]
  end

  def stop_bac_workers_and_wait(b)
    stop_ok, stop_mes = stop_bac_workers(b)
    return [ stop_ok, stop_mes ] if ! stop_ok # if we didn't even get an OK from stop action
    sleep 1
    # busy loop to wait for BAC workers to stop
    ntimes = 20 ; delay = 15  # total 5 minutes max
    num_active = "Unknown0"
    ntimes.times do |i|
      mess = " (Wait #{i+1}/#{ntimes})"
      print mess + ( "\b" * mess.size )
      info = b.remote_resource_info(:ping) rescue nil
      break if info.nil?
      #info = info.with_indifferent_access
      num_active = info[:bac_worker_pids].presence || "0"
      num_active = "0" if num_active == '???' # nils are transformed as that
      break if num_active == "0"
      break if num_active !~ /\A\d+/
      num_active = num_active.split(',').size.to_s
      break if num_active == "0"
      delay.times { |d| print [ '-', '\\', '|', '/' ][d % 4], "\b" ; sleep 1 }
    end
    print " " * 30 + "\b" * 30
    ok     = num_active == "0"
    mess   = "OK" if ok
    mess ||= "#{num_active} BAC workers still active" # message text used to abort sequence, see earlier in code
    [ ok , mess ]
  end

  def stop_bourreau(b) #:nodoc:
    r1=b.stop         rescue nil
    r2=b.stop_tunnels rescue nil
    b.update_attribute(:online, false)
    [ !!(r1 && r2) , "App: #{r1 or false}\tSSH Master: #{r2 or false}" ]
  end

  def stop_all_by_command(b)
    r1=b.send_command_stop_yourself rescue "(Exc)"
    r1=r1.command_execution_status if r1.is_a?(RemoteCommand)
    r2=b.stop_tunnels rescue nil
    b.update_attribute(:online, false)
    [ ((r1 == "OK") && r2.present?), "App: #{r1 or false}\tSSH Master: #{r2 or false}" ]
  end

  def start_bourreau(b) #:nodoc:
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
      bash_command_on_one_bourreau(bou,
        comm
        .gsub('@b@',bou.name)
        .gsub('@r@',bou.ssh_control_rails_dir.presence || "/no/rails"       )
        .gsub('@d@',bou.dp_cache_dir.presence          || "/no/dp_cachedir" )
        .gsub('@g@',bou.cms_shared_dir.presence        || "/no/gridshare"   )
      )
    end
  end

  def bash_command_on_one_bourreau(b,comm,&block) #:nodoc:
    if b.proxied_host.present? # another level of remote host... ?
      # ... then we prefix the remote command with another ssh call.
      comm = "ssh #{b.proxied_host.bash_escape} #{comm.bash_escape}"
    end
    if block_given?
      b.ssh_master.remote_shell_command_reader(comm,&block)
    else
      b.ssh_master.remote_shell_command_reader(comm)
    end
  end

end

(CbrainConsoleFeatures ||= []) << <<FEATURES
========================================================
Feature: Interactive Bourreau Control
========================================================
  ibc          # interactive CLI
  ibc "o p q"  # non-interactive

  This is an interactive tool with a built-in help,
  allowing the admin to start and stop bourreaux,
  and query their status etc. Useful during maintenance.
FEATURES

