
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

# A subclass of ClusterTask to run diagnostics.
class CbrainTask::Diagnostics < ClusterTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Overrides the default addlog() method such that each
  # log entry is also sent to STDOUT.
  def addlog(message,options={}) #:nodoc:
    puts "DIAGNOSTICS: #{self.bname_tid} #{message}" unless self.bourreau_id.blank?
    newoptions = options.dup
    newoptions[:caller_level] = 0 unless newoptions.has_key?(:caller_level)
    newoptions[:caller_level] += 1
    super(message,newoptions)
  end

  # Synchronize the userfiles given in argument, measuring
  # the performance (and success or failure).
  def setup #:nodoc:
    params       = self.params || {}

    file_ids     = params[:interface_userfile_ids] || []

    self.addlog "Starting diagnostics setup on #{file_ids.size} files."
    if params[:copy_number] && params[:copy_total]
      self.addlog "This task is copy #{params[:copy_number]} of #{params[:copy_total]}."
    end

    # Report environment
    %w[ CBRAIN_GLOBAL_BOURREAU_CONFIG_ID CBRAIN_GLOBAL_TOOL_CONFIG_ID CBRAIN_TOOL_CONFIG_ID ].each do |var|
       self.addlog("Environment check: #{var}=#{ENV[var] || "(Unset)"}")
    end

    # Check each input file
    file_ids.each do |id|
      u = Userfile.find(id) rescue nil
      unless u
        self.addlog("Cannot find Userfile '#{id}'.")
        next
      end
      mysize    = u.size || 0.0
      timestart = Time.now
      begin
        u.sync_to_cache
        difftime  = (0.0 + (Time.now - timestart))
        difftime  = 1.0 if difftime < 1.0
        bytes_per_sec = (0.0 + mysize) / difftime
        self.addlog "Synchronized: ID=#{id} NAME='#{u.name}' SIZE=#{mysize} TIME=#{difftime} AVG=#{bytes_per_sec} bytes/s"
      rescue => ex
        self.addlog "Failed Sync: ID=#{id} NAME='#{u.name}' SIZE=#{mysize} EXCEPT=#{ex.class} #{ex.message}"
      end
    end

    # Testing data providers
    dp_check_ids = params[:dp_check_ids] || []
    dp_check_ids.reject! { |id| id.blank? }
    if dp_check_ids.empty?
      self.addlog("No data provider checks to perform.")
    else
      dp_check_ids.each do |id|
        dp = DataProvider.find(id) rescue nil
        if ! dp
          self.addlog("Cannot find DataProvider ##{id}.")
          next
        end
        if ! dp.online
          self.addlog("Data Provider '#{dp.name}' is NOT ONLINE.")
          next
        end
        begin
          ok = dp.is_alive?
          if ok
            self.addlog("Data Provider '#{dp.name}' is ALIVE.")
          else
            self.addlog("Data Provider '#{dp.name}' is NOT ALIVE.")
          end
        rescue => ex
          self.addlog("Data Provider '#{dp.name}' is_alive?() RAISED EXCEPTION: #{ex.class}: #{ex.message}")
        end
      end
    end

    # Artifical delays
    setup_delay = params[:setup_delay] ? params[:setup_delay].to_i : 0
    if setup_delay > 0
      self.addlog "Sleeping for #{setup_delay} seconds."
      sleep setup_delay
    end

    # Artifical crash
    if mybool(params[:setup_crash])
      params[:setup_crash]=nil if mybool(params[:crash_will_reset])
      cb_error "This program crashed on purpose, as ordered."
    end

    return true
  end

  def job_walltime_estimate #:nodoc:
    params        = self.params || {}
    cluster_delay = params[:cluster_delay] ? params[:cluster_delay].to_i : 0
    walltime = 2.minutes + cluster_delay.seconds
    return walltime
  end

  # Creates a series of bash commands that will be run on the cluster.
  # The bash commands runs the 'wc' command on the SingleFiles given
  # in argument and the 'du' command on FileCollections. It also reports
  # several parameters about the environment.
  def cluster_commands #:nodoc:
    params       = self.params || {}

    if mybool(params[:no_cluster_job])
      self.addlog("No cluster job script to prepare.")
      File.open(self.stdout_cluster_filename,"w") { |fh| fh.write "Fake STDOUT output (because no cluster script)" }
      File.open(self.stderr_cluster_filename,"w") { |fh| fh.write "Fake STDERR output (because no cluster script)" }
      return nil
    end

    file_ids      = params[:interface_userfile_ids] || []

    # Note: 'commands' is an ARRAY of strings.
    commands = <<-"_DIAGNOSTIC_COMMANDS_".split(/\n/).map(&:strip)

      echo "===================================================================="
      echo "STDOUT Diagnostics Bash Script Starting `date`"
      echo "===================================================================="
      echo ""

      echo "====================================================================" 1>&2
      echo "STDERR Diagnostics Bash Script Starting `date`"                       1>&2
      echo "====================================================================" 1>&2
      echo ""                                                                     1>&2

      echo "==== CBRAIN Info ===="
      echo "Execution Server name: #{self.bourreau.try(:name).to_s.bash_escape}"
      echo ""

      echo "==== Host Info ===="
      uname -a
      uptime
      echo ""

      if test -f /etc/issue ; then
        echo "==== Issue ===="
        cat /etc/issue
        echo ""
      fi

      if test -f /etc/system-release ; then
        echo "==== System Release ===="
        cat /etc/system-release
        echo ""
      fi

      if test -n "`which lsb_release`" ; then
        echo "==== LSB Release ===="
        lsb_release -a
        echo ""
      fi

      if test -e /proc/cpuinfo ; then
        echo "==== CPU Info ===="
        cat /proc/cpuinfo | sort | uniq
        echo ""
      fi

      echo "==== Limits ===="
      ulimit -a
      echo ""

      echo "==== Environment ===="
      env | sort
      echo ""

    _DIAGNOSTIC_COMMANDS_

    file_ids.each do |id|
      u = Userfile.find(id) rescue nil
      next unless u
      full   = u.cache_full_path.to_s
      mysize = u.size || 0.0
      mytype = u.class.to_s
      commands << "\n"
      commands << "echo \"============================================================\""
      commands << "echo File=\\\"#{full.bash_escape}\\\""
      commands << "echo \"Size=#{mysize}\""
      commands << "echo \"Type=#{mytype}\""
      commands << "echo \"Start=`date`\""
      if u.is_a?(SingleFile)
        commands << "wc -c #{full.bash_escape} 2>&1"
      else
        commands << "du -s #{full.bash_escape} 2>&1"
      end
      commands << "echo \"End=`date`\""
    end

    cluster_delay = params[:cluster_delay] ? params[:cluster_delay].to_i : 0
    if cluster_delay > 0
      commands << "\n"
      commands << "echo \"============================================================\""
      commands << "echo \"Sleeping #{cluster_delay} seconds.\""
      commands << "sleep #{cluster_delay}"
    end

    commands << "\n"
    commands << "echo \"============================================================\""
    commands << "echo Diagnostics Script Ending\n" # we check for this sentence in save_results()
    commands << "\n"

    return commands
  end

  # Creates a report about the diagnostics generated and saves it
  # back to the CBRAIN DB. The report is mostly a concatenation
  # of the cluster job's STDOUT and STDERR.
  def save_results #:nodoc:
    params       = self.params || {}

    self.addlog "Starting diagnostics postprocessing."

    # Read cluster job's out and err files.
    stdout_text = File.read(self.stdout_cluster_filename) rescue nil
    stderr_text = File.read(self.stderr_cluster_filename) rescue "(Exception)"

    %w[ CBRAIN_GLOBAL_BOURREAU_CONFIG_ID CBRAIN_GLOBAL_TOOL_CONFIG_ID CBRAIN_TOOL_CONFIG_ID ].each do |var|
       self.addlog("Environment check: #{var}=#{ENV[var] || "(Unset)"}")
    end

    if ! mybool(params[:no_cluster_job])
      if stdout_text.nil? || stdout_text !~ /Diagnostics Script Ending/ # see end of cluster_commands()
        self.addlog "Error: cluster script did not produce expected output."
        self.addlog "Post Processing might have been triggered too soon."
        return false # -> "Failed On Cluster"
      end
    end

    if mybool(params[:cluster_crash])
      params[:cluster_crash]=nil if mybool(params[:crash_will_reset])
      self.addlog "Pretending that the cluster job failed."
      return false # -> "Failed On Cluster"
    end

    # Stuff needed for report
    dp_id   = self.results_data_provider_id
    report  = nil

    if dp_id  # creating the report is optional
      report = safe_userfile_find_or_new(TextFile,
            :name             => "Diagnostics-#{self.bname_tid_dashed}-#{self.run_number}.txt",
            :data_provider_id => dp_id
      )
    end

    if dp_id.blank?
      self.addlog("No Data Provider ID provided, so no report created.")
      params.delete(:report_id)
    elsif report.save
      self.addlog "Report entry created: #{report.name} (ID=#{report.id})"
      write_ok = report.cache_writehandle do |fh|
        fh.write( <<-"REPORT_DIAGNOSTICS" )

######################
# DIAGNOSTICS STDOUT #
######################

#{stdout_text}

######################
# DIAGNOSTICS STDERR #
######################

#{stderr_text}

        REPORT_DIAGNOSTICS
      end rescue nil
      if write_ok
        self.addlog "Report content saved properly to Data Provider '#{report.data_provider.name}'"
      else
        self.addlog "Report content COULD NOT be saved to Data Provider '#{report.data_provider.name}'"
      end
      self.addlog_to_userfiles_created(report)

      if mybool(params[:erase_report])
        self.addlog("Erasing report, as specified.")
        report.destroy
      else
        params[:report_id] = report.id
      end
    else
      self.addlog("Could not save report?!?")
      params.delete(:report_id)
    end

    postpro_delay = params[:postpro_delay] ? params[:postpro_delay].to_i : 0
    if postpro_delay > 0
      self.addlog "Sleeping for #{postpro_delay} seconds."
      sleep postpro_delay
    end

    if mybool(params[:postpro_crash])
      params[:postpro_crash]=nil if mybool(params[:crash_will_reset])
      cb_error "This program crashed on purpose, as ordered."
    end

    return true
  end



  #########################################
  # Recover/restart capabilities
  #########################################

  def recover_from_setup_failure #:nodoc:
    params = self.params
    return false unless mybool(params[:recover_setup])
    unless params[:recover_setup_delay].blank?
      sleep params[:recover_setup_delay].to_i
    end
    return true
  end

  def recover_from_cluster_failure #:nodoc:
    params = self.params
    return false unless mybool(params[:recover_cluster])
    unless params[:recover_cluster_delay].blank?
      sleep params[:recover_cluster_delay].to_i
    end
    return true
  end

  def recover_from_post_processing_failure #:nodoc:
    params = self.params
    return false unless mybool(params[:recover_postpro])
    unless params[:recover_postpro_delay].blank?
      sleep params[:recover_postpro_delay].to_i
    end
    return true
  end

  def restart_at_setup #:nodoc:
    params = self.params
    return false unless mybool(params[:restart_setup])
    unless params[:restart_setup_delay].blank?
      sleep params[:restart_setup_delay].to_i
    end
    return true
  end

  def restart_at_cluster #:nodoc:
    params = self.params
    return false unless mybool(params[:restart_cluster])
    unless params[:restart_cluster_delay].blank?
      sleep params[:restart_cluster_delay].to_i
    end
    return true
  end

  def restart_at_post_processing #:nodoc:
    params = self.params
    return false unless mybool(params[:restart_postpro])
    unless params[:restart_postpro_delay].blank?
      sleep params[:restart_postpro_delay].to_i
    end

    # We simply copy the out and err of the previous run when we restart at post-pro.
    cur_out = self.stdout_cluster_filename
    cur_err = self.stderr_cluster_filename
    if File.exists?(cur_out)
      system("cp",cur_out,self.stdout_cluster_filename(self.run_number + 1))
    end
    if File.exists?(cur_err)
      system("cp",cur_err,self.stderr_cluster_filename(self.run_number + 1))
    end
    return true
  end

  # My old convention was '1' for true, "" for false;
  # the new form helpers send '1' for true and '0' for false.
  private

  def mybool(value) #:nodoc:
    return false if value.blank?
    return false if value.is_a?(String)  and value == "0"
    return false if value.is_a?(Numeric) and value == 0
    return true
  end

end

