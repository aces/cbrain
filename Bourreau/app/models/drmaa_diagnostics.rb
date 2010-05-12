
#
# CBRAIN Project
#
# DrmaaDiagnostics subclass for running diagnostics
#
# Original author:
# Template author: Pierre Rioux
#
# $Id$
#

#A subclass of DrmaaTask to run diagnostics.
class DrmaaDiagnostics < DrmaaTask

  Revision_info="$Id$"

  # Overrides the default addlog() method such that each
  # log entry is also sent to STDOUT.
  def addlog(message,options={})
    puts "DIAGNOSTICS: #{self.bname_tid} #{message}" unless self.bourreau_id.blank?
    super(message,options.dup.merge( :caller_level => 1 ))
  end

  # Synchronize the userfiles given in argument, measuring
  # the performance (and success or failure).
  def setup
    params       = self.params
    user_id      = self.user_id

    files_hash   = params[:files_hash] || {}
    file_ids     = files_hash.values

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

    unless params[:setup_crash].blank?
      params[:setup_crash]=nil unless params[:crash_will_reset].blank?
      cb_error "This program crashed on purpose, as ordered."
    end

    true
  end

  # Creates a series of bash commands that will be run on the cluster.
  # The bash commands runs the 'wc' command on the SingleFiles given
  # in argument and the 'du' command on FileCollections. It also reports
  # several parameters about the environment.
  def drmaa_commands
    params       = self.params
    user_id      = self.user_id

    files_hash    = params[:files_hash] || {}
    file_ids      = files_hash.values

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
  def save_results
    params       = self.params
    user_id      = self.user_id

    self.addlog "Starting diagnostics postprocessing."

    unless params[:cluster_crash].blank?
      params[:cluster_crash]=nil unless params[:crash_will_reset].blank?
      self.addlog "Pretending that the cluster job failed."
      return false
    end

    # Stuff needed for report
    dp_id   = params[:data_provider_id]
    myuser  = User.find(user_id)
    mygroup = myuser.own_group
    report  = nil

    if dp_id  # creating the report is optional
      report_attributes = {
                               :name             => "Diagnostics-#{self.bname_tid_dashed}-#{self.run_number}.txt",
                               :user_id          => myuser.id,
                               :group_id         => mygroup.id,
                               :data_provider_id => dp_id,
                               :task             => 'Bourreau Diagnostics'
                          }
      report = SingleFile.find(:first, :conditions => report_attributes) || SingleFile.new(report_attributes)
    end

    if dp_id.blank?
      self.addlog("No Data Provider ID provided, so no report created.")
    elsif report.save
      report.cache_writehandle do |fh|
        stdout_text = File.read(self.stdoutDRMAAfilename) rescue "(Exception)"
        stderr_text = File.read(self.stderrDRMAAfilename) rescue "(Exception)"
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
    else
      self.addlog("Could not save report?!?")
    end

    postpro_delay = params[:postpro_delay] ? params[:postpro_delay].to_i : 0
    if postpro_delay > 0
      self.addlog "Sleeping for #{postpro_delay} seconds."
      sleep postpro_delay
    end

    unless params[:postpro_crash].blank?
      params[:postpro_crash]=nil unless params[:crash_will_reset].blank?
      cb_error "This program crashed on purpose, as ordered."
    end

    true
  end



  #########################################
  # Recover/restart capabilities
  #########################################

  def recover_from_setup_failure
    params = self.params
    return false if params[:recover_setup].blank?
    unless params[:recover_setup_delay].blank? 
      sleep params[:recover_setup_delay].to_i
    end
    true
  end

  def recover_from_cluster_failure
    params = self.params
    return false if params[:recover_cluster].blank?
    unless params[:recover_cluster_delay].blank? 
      sleep params[:recover_cluster_delay].to_i
    end
    true
  end

  def recover_from_post_processing_failure
    params = self.params
    return false if params[:recover_postpro].blank?
    unless params[:recover_postpro_delay].blank? 
      sleep params[:recover_postpro_delay].to_i
    end
    true
  end

  def restart_at_setup
    params = self.params
    return false if params[:restart_setup].blank?
    unless params[:restart_setup_delay].blank? 
      sleep params[:restart_setup_delay].to_i
    end
    true
  end

  def restart_at_cluster
    params = self.params
    return false if params[:restart_cluster].blank?
    unless params[:restart_cluster_delay].blank? 
      sleep params[:restart_cluster_delay].to_i
    end
    true
  end

  def restart_at_post_processing
    params = self.params
    return false if params[:restart_postpro].blank?
    unless params[:restart_postpro_delay].blank? 
      sleep params[:restart_postpro_delay].to_i
    end
    true
  end

end

