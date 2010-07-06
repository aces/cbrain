
#
# CBRAIN Project
#
# CbrainTask subclass for running diagnostics
#
# Original author:
# Template author: Pierre Rioux
#
# $Id$
#

#A subclass of ClusterTask to run diagnostics.
class CbrainTask::Diagnostics < ClusterTask

  Revision_info="$Id$"

  # Overrides the default addlog() method such that each
  # log entry is also sent to STDOUT.
  def addlog(message,options={}) #:nodoc:
    puts "DIAGNOSTICS: #{self.bname_tid} #{message}" unless self.bourreau_id.blank?
    super(message,options.dup.merge( :caller_level => 1 ))
  end

  # Synchronize the userfiles given in argument, measuring
  # the performance (and success or failure).
  def setup #:nodoc:
    params       = self.params || {}
    user_id      = self.user_id

    file_ids     = params[:interface_userfile_ids] || []

    self.addlog "Starting diagnostics setup on #{file_ids.size} files."
    if params[:copy_number] && params[:copy_total]
      self.addlog "This task is copy #{params[:copy_number]} of #{params[:copy_total]}."
    end

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

    setup_delay = params[:setup_delay] ? params[:setup_delay].to_i : 0
    if setup_delay > 0
      self.addlog "Sleeping for #{setup_delay} seconds."
      sleep setup_delay
    end

    if mybool(params[:setup_crash])
      params[:setup_crash]=nil if mybool(params[:crash_will_reset])
      cb_error "This program crashed on purpose, as ordered."
    end

    true
  end

  # Creates a series of bash commands that will be run on the cluster.
  # The bash commands runs the 'wc' command on the SingleFiles given
  # in argument and the 'du' command on FileCollections. It also reports
  # several parameters about the environment.
  def cluster_commands #:nodoc:
    params       = self.params || {}
    user_id      = self.user_id

    file_ids      = params[:interface_userfile_ids] || []

    # Note: 'commands' is an ARRAY of strings.
    commands = <<-"_DIAGNOSTIC COMMANDS_".split(/\n/).map &:strip

      echo "============================================================="
      echo "Diagnostics Bash Script Starting `date`"
      echo "============================================================="
      echo ""

      echo "---- Host Info ---"
      hostname
      uname -a
      uptime
      echo ""

      echo "---- Environment ---"
      env
      echo ""

    _DIAGNOSTIC COMMANDS_

    file_ids.each do |id|
      u = Userfile.find(id) rescue nil
      next unless u
      full   = u.cache_full_path
      mysize = u.size || 0.0
      mytype = u.class.to_s
      commands << "echo \"============================================================\""
      commands << "echo \"File=#{full}\""
      commands << "echo \"Size=#{mysize}\""
      commands << "echo \"Type=#{mytype}\""
      commands << "echo \"Start=`date`\""
      if mytype == 'SingleFile'
        commands << "wc -c #{full}"
      else
        commands << "du -s #{full}"
      end
      commands << "echo \"End=`date`\""
    end

    cluster_delay = params[:cluster_delay] ? params[:cluster_delay].to_i : 0
    if cluster_delay > 0
      commands << "\n"
      commands << "echo \"============================================================\""
      commands << "echo \"Sleeping #{cluster_delay} seconds.\""
      commands << "sleep #{cluster_delay}"
      commands << "\n"
    end

    commands
  end
  
  # Creates a report about the diagnostics generated and saves it
  # back to the CBRAIN DB. The report is mostly a concatenation
  # of the cluster job's STDOUT and STDERR.
  def save_results #:nodoc:
    params       = self.params || {}
    user_id      = self.user_id

    self.addlog "Starting diagnostics postprocessing."

    if mybool(params[:cluster_crash])
      params[:cluster_crash]=nil if mybool(params[:crash_will_reset])
      self.addlog "Pretending that the cluster job failed."
      return false
    end

    # Stuff needed for report
    dp_id   = params[:data_provider_id]
    myuser  = User.find(user_id)
    mygroup = myuser.own_group
    report  = nil

    if dp_id  # creating the report is optional
      report = safe_userfile_find_or_new(SingleFile,
            :name             => "Diagnostics-#{self.bname_tid_dashed}-#{self.run_number}.txt",
            :user_id          => myuser.id,
            :group_id         => mygroup.id,
            :data_provider_id => dp_id,
            :task             => 'Bourreau Diagnostics'
      )
    end

    if dp_id.blank?
      self.addlog("No Data Provider ID provided, so no report created.")
      params.delete(:report_id)
    elsif report.save
      report.cache_writehandle do |fh|
        stdout_text = File.read(self.stdout_cluster_filename) rescue "(Exception)"
        stderr_text = File.read(self.stderr_cluster_filename) rescue "(Exception)"
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
      end
      params[:report_id] = report.id
      self.addlog_to_userfiles_created(report)
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

    true
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
    true
  end

  def recover_from_cluster_failure #:nodoc:
    params = self.params
    return false unless mybool(params[:recover_cluster])
    unless params[:recover_cluster_delay].blank? 
      sleep params[:recover_cluster_delay].to_i
    end
    true
  end

  def recover_from_post_processing_failure #:nodoc:
    params = self.params
    return false unless mybool(params[:recover_postpro])
    unless params[:recover_postpro_delay].blank? 
      sleep params[:recover_postpro_delay].to_i
    end
    true
  end

  def restart_at_setup #:nodoc:
    params = self.params
    return false unless mybool(params[:restart_setup])
    unless params[:restart_setup_delay].blank? 
      sleep params[:restart_setup_delay].to_i
    end
    true
  end

  def restart_at_cluster #:nodoc:
    params = self.params
    return false unless mybool(params[:restart_cluster])
    unless params[:restart_cluster_delay].blank? 
      sleep params[:restart_cluster_delay].to_i
    end
    true
  end

  def restart_at_post_processing #:nodoc:
    params = self.params
    return false unless mybool(params[:restart_postpro])
    unless params[:restart_postpro_delay].blank? 
      sleep params[:restart_postpro_delay].to_i
    end
    true
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

