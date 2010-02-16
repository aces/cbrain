
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

  def addlog(message,options={})
    puts "DIAGNOSTIC: #{message}"
    super(message,options.dup.merge( :caller_level => 1 ))
  end

  #See DrmaaTask.
  def setup
    params       = self.params
    user_id      = self.user_id

    files_hash    = params[:files_hash] || {}
    file_ids      = files_hash.values

    self.addlog "Starting diagnostics on #{file_ids.size} files"

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

    true
  end

  #See DrmaaTask.
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

    delay = params[:delay_seconds].to_i rescue nil
    if delay && delay > 0
      commands << "\n"
      commands << "echo \"============================================================\""
      commands << "echo \"Sleeping #{delay} seconds.\""
      commands << "sleep #{delay}"
      commands << "\n"
    end

    commands
  end
  
  #See DrmaaTask.
  def save_results
    params       = self.params
    user_id      = self.user_id

    myuser = User.find(user_id)
    mygroup = myuser.own_group

    report = SingleFile.new( :name             => "Diagnostics-" + self.bname_tid_dashed + ".txt",
                             :user_id          => myuser.id,
                             :group_id         => mygroup.id,
                             :data_provider_id => params[:data_provider_id],
                             :task             => 'Bourreau Diagnostics'
                           )

    if report.save
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

    true
  end

end

