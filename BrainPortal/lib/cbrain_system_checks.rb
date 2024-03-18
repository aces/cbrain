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

# Runtime system checks common to both Portal and Bourreau
class CbrainSystemChecks < CbrainChecker #:nodoc:

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.puts(*args) #:nodoc:
    Rails.logger.info("\e[33m" + args.join("\n") + "\e[0m") rescue nil
    Kernel.puts(*args)
  end



  def self.print_intro_info #:nodoc:
    #-----------------------------------------------------------------------------
    puts "C> CBRAIN System Checks starting, " + Time.now.to_s
    puts "C> Ruby #{RUBY_VERSION} on Rails #{Rails::VERSION::STRING}, environment is set to '#{Rails.env}'"
    puts "C> RAILS_ENV variable is set to '#{ENV['RAILS_ENV']}'" if (! ENV['RAILS_ENV'].blank?) && (Rails.env != ENV['RAILS_ENV'])
    puts "C> CBRAIN instance is named '#{CBRAIN::Instance_Name}'"
    puts "C> Hostname is '#{Socket.gethostname rescue "(Exception)"}'"
    #-----------------------------------------------------------------------------
  end



  # First thing first: identify which RemoteResource object
  # represents the current Rails application.
  def self.a002_ensure_Rails_can_find_itself #:nodoc:

    #-----------------------------------------------------------------------------
    puts "C> Ensuring that this CBRAIN app is registered in the DB..."
    #-----------------------------------------------------------------------------

    myname       = ENV["CBRAIN_RAILS_APP_NAME"]
    myname     ||= CBRAIN::CBRAIN_RAILS_APP_NAME if CBRAIN.const_defined?('CBRAIN_RAILS_APP_NAME')
    mytype       = Rails.root.to_s =~ /BrainPortal\z/ ? "BrainPortal" : "Bourreau"
    myshorttype  = Rails.root.to_s =~ /BrainPortal\z/ ? "portal"      : "bourreau"
    if myname.blank?
      puts "C> \t- No name given to this #{mytype} Rails application."
      puts "C> \t  Please edit 'config/initializers/config_#{myshorttype}.rb' and"
      puts "C> \t  give it a name by setting the value of 'CBRAIN_RAILS_APP_NAME'."
      if mytype == "BrainPortal"
        puts "C> \t- If this is a new CBRAIN installation, you might want to consider instead"
        puts "C> \t  running this command: 'rake db:seed RAILS_ENV=#{Rails.env}'."
        puts "C> \t  IMPORTANT NOTE: this rake task will also destroy any existing database, if any!"
      end
      show_portals_list(mytype)
      Kernel.exit(10)
    end

    # Find myself.
    rr = Class.const_get(mytype).find_by_name(myname)

    if rr
      # The most important global assignment in the CBRAIN system!
      CBRAIN.const_set("SelfRemoteResourceId",rr.id)
      rr.update_attributes( :online => true ) unless rr.online?
      puts "C> \t- This CBRAIN app is named '#{rr.name}' and is registered."
      return true # everything OK
    end

    if mytype == "BrainPortal"
      puts "C> \t- BrainPortal named '#{myname}' is not registered in database, please run"
      puts "C> \t  this command: 'rake db:seed RAILS_ENV=#{Rails.env}'."
    else
      puts "C> \t- Bourreau named '#{myname} is not registered in database, please add"
      puts "C> \t  it using the interface, or check the value of 'CBRAIN_RAILS_APP_NAME' in"
      puts "C> \t  'config/initializers/config_#{myshorttype}.rb'"
    end

    show_portals_list(mytype)
    Kernel.exit(10)
  end



  # Checks that the Sys::Proctable gem is properly installed (it
  # has a special manual installation step that people sometimes forget)
  def self.a007_check_sys_proctable #:nodoc:

    #-----------------------------------------------------------------------------
    puts "C> Ensuring that the Sys::ProcTable gem is operational..."
    #-----------------------------------------------------------------------------

    my_own_process = Sys::ProcTable.ps(:pid => Process.pid)
    puts "C> \t- All good. Found process name: #{my_own_process.name}"
  rescue => ex
    puts "C> \t- Error: it seems Sys::ProcTable doesn't work. Did you run the rake task"
    puts "C> \t  like it says in the installation instructions?"
    puts "#{ex.class} #{ex.message}"
    puts ex.backtrace.join("\n") + "\n"
    Kernel.exit(10)
  end



  # Checks for a proper timezone configuration in Rails' environment.
  def self.a009_check_time_zone_configuration #:nodoc:

    #-----------------------------------------------------------------------------
    puts "C> Setting time zone for application..."
    #-----------------------------------------------------------------------------

    myself = RemoteResource.current_resource
    my_time_zone = myself.time_zone

    if my_time_zone.blank? || ActiveSupport::TimeZone[my_time_zone].blank?
      puts "C> \t- Warning: time zone not set properly for this Rails app, setting it to UTC."
      my_time_zone = 'UTC'
      myself.time_zone = my_time_zone
      myself.save
    else
      puts "C> \t- Time zone set to '#{my_time_zone}'."
    end

    if myself.is_a? BrainPortal
      CbrainRailsPortal::Application.config.time_zone = my_time_zone
    elsif myself.is_a? Bourreau
      CbrainRailsBourreau::Application.config.time_zone = my_time_zone
    end
    Time.zone = my_time_zone

  end



  def self.a040_ensure_file_revision_system_is_active #:nodoc:

    #-----------------------------------------------------------------------------
    puts "C> Making sure we can track file revision numbers."
    #-----------------------------------------------------------------------------

    rev = DataProvider.revision_info.self_update
    # Invalid rev dates are 0000-00-00 or before 1971
    if (rev.date !~ /(\d\d\d\d)/ || Regexp.last_match[1].to_i < 1971)
      puts "C> \t- Error: We don't have a working mechanism for tracking revision numbers."
      puts "C> \t  Either GIT isn't installed and in your path, or the static file with"
      puts "C> \t  the list of revision numbers for CbrainFileRevision is missing."
      Kernel.exit(10)
    end
    mode = CbrainFileRevision.git_available? ? 'git' : 'static CSV files'
    puts "C> \t- Revisions are fetched using: #{mode}"

  end



  # Cleans up old syncstatus that are left in the database
  def self.a045_ensure_syncstatus_is_clean #:nodoc:

    #-----------------------------------------------------------------------------
    puts "C> Cleaning up old SyncStatus objects..."
    #-----------------------------------------------------------------------------

    rr_ids = RemoteResource.where({}).raw_first_column(:id)
    bad_ss = SyncStatus.where([ "remote_resource_id NOT IN (?)", rr_ids ])
    ss_deleted = bad_ss.count
    if ss_deleted > 0
      bad_ss.destroy_all rescue true
      puts "C> \t- Removed #{ss_deleted} old SyncStatus objects associated with obsolete resources."
    else
      puts "C> \t- No SyncStatus objects are associated with obsolete resources."
    end
    ss_uids = SyncStatus.where({}).raw_first_column(:userfile_id) || []
    uids    = Userfile.where({}).raw_first_column(:id)            || []
    bad_ids = (ss_uids - uids).uniq
    if bad_ids.size > 0
      SyncStatus.where(:userfile_id => nil).destroy_all rescue true
      SyncStatus.where(:userfile_id => bad_ids.compact).destroy_all rescue true
      puts "C> \t- Removed #{bad_ids.size} old SyncStatus objects associated with obsolete files."
    else
      puts "C> \t- No SyncStatus objects are associated with obsolete files."
    end

    #-----------------------------------------------------------------------------
    puts "C> Handling duplicated SyncStatus objects..." # very rare normally
    #-----------------------------------------------------------------------------
    myself = RemoteResource.current_resource
    report = SyncStatus.clean_duplications(myself.id)
    report.each do |pair,count|
      puts "C> \t- #{count} x (#{pair[0]},#{pair[1]})"
    end
    puts "C> \t- No duplicated SyncStatus objects found." if report.blank?

  end



  def self.a050_check_data_provider_cache_wipe #:nodoc:

    #-----------------------------------------------------------------------------
    puts "C> Checking to see if Data Provider cache is valid..."
    #-----------------------------------------------------------------------------

    myself         = RemoteResource.current_resource

    cache_root     = DataProvider.cache_rootdir rescue nil
    # Need to perform a `to_s` due to a strange behaviour of `blank?` 
    # on `Pathname` (if a content of a `Pathname` is empty it will return true)
    if cache_root.to_s.blank?
      puts "C> \t- SKIPPING! No cache root directory yet configured!"
      return
    end

    # Case 1: DIR contains an ID, which differ from what we have for ourself
    # We consider this always bad, even when our own ID is still nil.
    md5 = DataProvider.cache_md5 # just reads the file if it exists
    if md5 && myself.cache_md5 != md5 # we do want to compare with a nil value for myself.cache_md5
      puts "C> \t- Error: Cache root directory (#{cache_root}) seems already in use by another server!"
      puts "C> \t  To force this server to use that directory as cache root, remove the files"
      puts "C> \t  '#{DataProvider::DP_CACHE_ID_FILE}' and '#{DataProvider::DP_CACHE_MD5_FILE}' from it."
      Kernel.exit(10)
    end

    # Check all sort of other properties: path conflicts, presence of dir, permissions etc
    begin
      DataProvider.this_is_a_proper_cache_dir! cache_root,
        :local => true,
        :key   => myself.cache_md5, # could be nil, in that case it won't cross-check
        :host  => Socket.gethostname,
        :for_remote_resource_id => myself.id
    rescue => ex
      puts "C> \t- SKIPPING! Invalid cache root directory '#{cache_root}' :"
      puts "C> \t  #{ex.message}"
      puts "C> \t  Fix with the interface, please."
      puts "C> \t  (Change the path or clean it up, and make sure it's not used for anything else)"
      return
    end

    # Case 2: Path is OK but DIR has yet no ID so we create one and record it.
    # We crush whatever ID we already had.
    if md5.blank?
      puts "C> \t- Recording new DataProvider MD5 ID in database."
      md5 = DataProvider.create_cache_md5
      myself.update_attributes( :cache_md5 => md5 )
    end

    DataProvider.revision_info.self_update # just to make sure we have it
    dp_disk_rev = DataProvider.cache_revision_of_last_init rescue nil # will be "Unknown" if unknown, nil if erroneous
    dp_code_rev = DateTime.parse("#{DataProvider.revision_info.date} #{DataProvider.revision_info.time}") rescue nil
    dp_need_rev = DateTime.parse(DataProvider::DataProviderCache_RevNeeded) rescue nil

    raise "Serious Internal Error: I cannot get a 'code' DateTime revision value for DataProvider?!?" unless
      dp_code_rev.is_a?(DateTime)
    raise "Serious Internal Error: I cannot get a 'need' DateTime revision value from DataProvider hardcoded constant?!?" unless
      dp_need_rev.is_a?(DateTime)
    raise "Serious Internal Error: DataProvider 'code' DateTime (#{dp_code_rev.inspect}) is earlier than 'need' DateTime (#{dp_need_rev.inspect}) ?!?" if
      dp_code_rev < dp_need_rev

    if dp_disk_rev.nil? # NIL check important, see method above
      puts "C> \t- SKIPPING! Cache root directory '#{cache_root}' is invalid! Fix with the interface, please."
      return
    end

    cache_dir_mode = File.stat(cache_root).mode
    if (cache_dir_mode & 0777) != 0700
      puts "C> \t- WARNING! Cache root directory '#{cache_root}' has invalid permissions #{sprintf("%4.4o",cache_dir_mode & 0777)}. Fixing to 0700."
      File.chmod(0700,cache_root)
    end

    #-----------------------------------------------------------------------------
    puts "C> Checking to see if Data Provider cache needs cleaning up..."
    #-----------------------------------------------------------------------------

    # TOTAL wipe needed ?
    if ( ! dp_disk_rev.is_a?(DateTime) ) || dp_disk_rev < dp_need_rev # Before Pierre's upgrade

      puts "C> \t- Data Provider Cache needs to be fully wiped..."
      puts "C> \t  Disk Rev: '#{dp_disk_rev.inspect}'"
      puts "C> \t  Need Rev: '#{dp_need_rev.inspect}'"
      puts "C> \t  Code Rev: '#{dp_code_rev.inspect}'"
      puts "C> \t- WARNING: This could take a long time so you should not"
      puts "C> \t  start another instance of this Rails application."
      Dir.chdir(cache_root) do
        dir_to_remove  = ".OLD_being_wiped.#{Process.pid}"
        Dir.foreach(".") do |entry|
          next unless File.directory?(entry) && entry =~ /\A\d\d+\z/ # only subdirectories named '00', '123' etc
          Dir.mkdir(dir_to_remove,0700) unless File.directory?(dir_to_remove)
          newname    = "#{dir_to_remove}/#{entry}"
          renamed_ok = File.rename(entry,newname) rescue false
          if renamed_ok
            puts "C> \t\t- Removing old cache subdirectory '#{entry}' (in background)."
          end
        end
        system("{ /bin/rm -rf #{dir_to_remove.bash_escape} </dev/null >/dev/null 2>&1 & } &") if File.directory?(dir_to_remove)
      end
      puts "C> \t- Synchronization objects are being wiped."
      SyncStatus.where( :remote_resource_id => myself.id ).destroy_all
      puts "C> \t- Re-recording DataProvider 'code' DateTime in cache."
      DataProvider.cache_revision_of_last_init(:force)

    # Just crud removal needed.
    else

      puts "C> \t- Wiping old files in Data Provider cache (in background)."

      CBRAIN.spawn_with_active_records(User.admin, "CacheCleanup") do
        wiped = DataProvider.cleanup_leftover_cache_files("Yeah, Do it!", :update_dollar_zero => true) rescue []
        unless wiped.empty?
          Rails.logger.info "Wiped #{wiped.size} old files in DP cache."
          Message.send_message(User.admin,
            :type          => :system,
            :header        => "Report of cache crud removal on #{myself.is_a?(BrainPortal) ? "Portal" : "Execution Server"} '#{myself.name}'",
            :description   => "These relative paths in the local Data Provider cache were\n" +
                              "removed as there are no longer any userfiles matching them.\n",
            :variable_text => "#{wiped.size} cache subpaths:\n" + wiped.sort
                              .each_slice(10).map { |pp| pp.join(" ") }.join("\n"),
            :critical      => true,
            :send_email    => false
          ) rescue true
        end
      end

    end
  end

  # prevents archiving/delete of cbrain system files and top directories, related to
  # cache and gridshare
  def self.a060_ensure_system_files_will_not_be_deleted #:nodoc:

    #-----------------------------------------------------------------------------
    puts "C> Updating timestamp for important system files and directories"
    #-----------------------------------------------------------------------------

    cache_root = DataProvider.cache_rootdir rescue nil
    # Need to perform a `to_s` due to a strange behaviour of `blank?`
    # on `Pathname` (if a content of a `Pathname` is empty it will return true)
    if cache_root.to_s.blank?
      puts "C> \t- SKIPPING! No cache root directory yet configured!"
      return
    end

    DataProvider.system_touch
  end


  def self.a080_ensure_set_starttime_revision #:nodoc:
    #-----------------------------------------------------------------------------
    puts  "C> Current application tag or revision: #{CBRAIN::CBRAIN_StartTime_Revision}"
    puts  "C> Current Git branch: #{CBRAIN::CBRAIN_Git_Branch.presence || "unknown"}"
    #-----------------------------------------------------------------------------
  end



  private

  # Shows a list of currently configured BrainPortals
  def self.show_portals_list(type) #:nodoc:
    portals = Class.const_get(type).all
    return if portals.size == 0
    puts "C> \t- Note: there are already #{portals.size} #{type} records registered:"
    portals.each do |p|
      puts "C> \t\t- #{type} record named '#{p.name}' was created #{p.created_at}"
    end
    puts "C> \t- It's possible you need to set the value of CBRAIN_RAILS_APP_NAME to"
    puts "C> \t  #{portals.size > 1 ? "one of these names." : "this name."}"
  end

end
