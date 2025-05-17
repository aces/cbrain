
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

require 'socket'

class BourreauSystemChecks < CbrainChecker #:nodoc:

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.puts(*args) #:nodoc:
    Rails.logger.info("\e[33m" + args.join("\n") + "\e[0m") rescue nil
    Kernel.puts(*args)
  end



  def self.a000_ensure_models_are_preloaded #:nodoc:
    # There's a piece of code at the end of each of these models
    # which forces the pre-load of all their subclasses.
    ClusterTask.nil? # not PortalTask, which is only on the BrainPortal rails app
    BackgroundActivity.nil?
    ClusterTask.preload_subclasses
    BackgroundActivity.preload_subclasses
  end



  def self.a005_ensure_boutiques_descriptors_are_loaded #:nodoc:
    #-----------------------------------------------------------------------------
    puts "C> Associating Boutiques Descriptors With ToolConfigs"
    #-----------------------------------------------------------------------------
    BoutiquesBootIntegrator.link_all
  end



  def self.a025_check_single_table_inheritance_types #:nodoc:

    #-----------------------------------------------------------------------------
    puts "C> Checking 'type' columns for single table inheritance..."
    #-----------------------------------------------------------------------------

    myself      = RemoteResource.current_resource
    err_or_warn = Rails.env == 'production' ? 'Error' : 'Warning'
    errcount    = 0

    [
      (myself.is_a?(Bourreau) ? CbrainTask.where(:bourreau_id => myself.id) : CbrainTask),
      CustomFilter,
      User,
      RemoteResource,
      DataProvider,
      BackgroundActivity,
      ResourceUsage,
    ].each do |query|
      badtypes = query.distinct(:type).pluck(:type).compact
        .reject { |type| type.safe_constantize }
      next if badtypes.empty?
      puts "C> \t- #{err_or_warn}: Bad type values in table '#{query.table_name}': #{badtypes.join(', ')}"
      errcount += 1
    end

    raise "Single table inheritance check failed for #{errcount} tables" if Rails.env == 'production' && errcount > 0

  end



  def self.a050_ensure_proper_cluster_management_layer_is_loaded #:nodoc:

    #-----------------------------------------------------------------------------
    puts "C> Loading cluster management SCIR class..."
    #-----------------------------------------------------------------------------

    myself        = RemoteResource.current_resource
    cluster_type  = myself.cms_class.presence
    raise "CBRAIN configuration error: cluster type is unset." if cluster_type.blank?
    cluster_class = cluster_type.constantize rescue nil
    raise "CBRAIN configuration error: cluster type is set to an invalid Scir class name '#{cluster_type}'." if (! cluster_class) || (! (cluster_class < Scir))
    session = myself.scir_session
    rev = session.revision_info.format("%f %s %a %d") # loads it?
    puts "C> \t- Layer for '#{cluster_class}' #{rev} loaded."
  end




  def self.a075_ensure_task_workdirs_still_exist #:nodoc:

    myself        = RemoteResource.current_resource
    gridshare_dir = myself.cms_shared_dir

    return unless Dir.exists?(gridshare_dir)

    #-----------------------------------------------------------------------------
    puts "C> Making sure work directories for local tasks exist (in background)"
    #-----------------------------------------------------------------------------

    BackgroundActivity::CheckMissingWorkdir.setup!

  end



  def self.a076_ensure_task_archived_status_is_consistent #:nodoc:

    #-----------------------------------------------------------------------------
    puts "C> Verifying CbrainTasks with inconsistent archiving information..."
    #-----------------------------------------------------------------------------

    # 4 valid cases
    # CASE workdir_archived?  workdir_archive_userfile_id (waui)  cluster_workdir_size (cws)
    # A    false,             nil,                                nil,    # workdir doesn't exist, and no archive known
    # B    false,             nil,                                size,   # workdir exists on cluster, no archive known
    # C    true,              nil,                                size,   # workdir exists on cluster, archive is there
    # D    true,              id,                                 nil,    # workdir doesn't exist, archived as file

    # 4 invalid cases
    # CASE workdir_archived?  workdir_archive_userfile_id (waui)  cluster_workdir_size (cws)
    # 1    true,              nil,                                nil,    # workdir_archived? should be turned to false
    # 2    false,             id,                                 nil,    # workdir_archived? should be turned to true
    # 3    false,             id,                                 size,   # If waui and cws: verify existence of waui if it exist turn cws to nil and turn workdir_archived to true
    # 4    true,              id,                                 size,   # If waui and cws: verify existence of waui if it exist turn cws to nil

    # Other cases:
    # 5 workdir_archived == true but the task have no workdir_archive.    # workdir_archived? should be turned false

    myself      = RemoteResource.current_resource
    local_tasks = CbrainTask.where(:bourreau_id => myself.id)

    # CASE 1
    case1_tasks = local_tasks.where(:workdir_archived => true, :workdir_archive_userfile_id => nil, :cluster_workdir_size => nil)
    case1_count = case1_tasks.count
    puts "C> \t- Processing #{case1_count} CbrainTasks that seem to be archived but missing their archiving information." if case1_count > 0
    case1_tasks.all.each do |t|
      t.addlog("INCONSISTENCY REPAIR: This task was marked as archived but the archiving information was lost")
      t.workdir_archived = false # turn to CASE A
      t.save
    end

    # CASE 2
    case2_tasks = local_tasks.where(:workdir_archived => false, :cluster_workdir_size => nil).where("workdir_archive_userfile_id IS NOT null")
    case2_count = case2_tasks.count
    puts "C> \t- Processing #{case2_count} CbrainTasks that seem to be archived as a file but are not marked as archived." if case2_count > 0
    case2_tasks.all.each do |t|
      userfile_id = t.workdir_archive_userfile_id
      tarch       = TaskWorkdirArchive.where(:id => userfile_id).first
      if tarch && (tarch.size.nil? || tarch.size == 0) # bad upload of archive
        tarch.destroy rescue nil
        tarch = nil
      end
      if tarch # turn CASE D
        t.addlog("INCONSISTENCY REPAIR: This task was marked as not archived but it was linked to a file archive")
        t.workdir_archived = true
      else # turn CASE A
        t.addlog("INCONSISTENCY REPAIR: This task was linked to an invalid file archive")
        t.workdir_archive_userfile_id = nil
      end
      t.save
    end

    # CASE 3 and CASE 4
    case3_and_case4_tasks = local_tasks.where("workdir_archive_userfile_id IS NOT null").where("cluster_workdir_size IS NOT null")
    case3_and_case4_count = case3_and_case4_tasks.count
    puts "C> \t- Processing #{case3_and_case4_count} CbrainTasks that seem to be archived both as a file and on cluster." if case3_and_case4_count > 0
    case3_and_case4_tasks.all.each do |t|
      userfile_id = t.workdir_archive_userfile_id
      tarch       = TaskWorkdirArchive.where(:id => userfile_id).first
      if tarch && (tarch.size.nil? || tarch.size == 0) # bad upload of archive
        tarch.destroy rescue nil
        tarch = nil
      end
      if tarch # turn to case D
        t.addlog("INCONSISTENCY REPAIR: This task was marked archived both as a file and on cluster (cluster archive was invalid)")
        t.workdir_archived     = true
        t.cluster_workdir_size = nil
      else # turn to case C
        t.addlog("INCONSISTENCY REPAIR: This task was marked archived both as a file and on cluster (file archive was invalid)")
        t.workdir_archive_userfile_id = nil
      end
      t.save
    end

    # CASE 5
    tasks_archived_as_file = local_tasks.archived_as_file
    valid_tasks_ids        = tasks_archived_as_file.joins(:workdir_archive).pluck("cbrain_tasks.id").compact
    all_tasks_ids          = tasks_archived_as_file.pluck("cbrain_tasks.id")
    case5_tasks            = CbrainTask.find(all_tasks_ids - valid_tasks_ids)
    case5_count            = case5_tasks.size
    puts "C> \t- Processing #{case5_count} CbrainTasks that seem to be archived but that haven't workdir_archive." if case5_count > 0
    case5_tasks.each do |t|
      t.addlog("INCONSISTENCY REPAIR: This task was marked as archived but doesn't have a corresponding archive file.")
      t.workdir_archived            = false # turn to CASE A
      t.workdir_archive_userfile_id = nil
      t.save
    end


    total_count = case1_count + case2_count + case3_and_case4_count + case5_count
    puts "C> \t- No tasks need to be updated." if total_count == 0

  end



  def self.a080_ensure_tasks_have_workdir_sizes #:nodoc:

    #-----------------------------------------------------------------------------
    puts "C> Refreshing the disk sizes for workdirs of CbrainTasks..."
    #-----------------------------------------------------------------------------

    myself        = RemoteResource.current_resource
    gridshare_dir = myself.cms_shared_dir

    if gridshare_dir.blank? || ! Dir.exists?(gridshare_dir)
      puts "C> \t- SKIPPING! No global task work directory yet configured!"
      return
    end

    local_tasks_not_sized = CbrainTask.where(
      :bourreau_id          => myself.id,
      :status               => ( CbrainTask::COMPLETED_STATUS + CbrainTask::FAILED_STATUS ) - CbrainTask::ACTIVE_STATUS,
      :cluster_workdir_size => nil,
    ).where(
      [ "updated_at < ?", 1.day.ago ], # just to be safe...
    ).where(
      "cluster_workdir IS NOT NULL"
    )

    how_many = local_tasks_not_sized.count
    if how_many == 0
      puts "C> \t- No tasks need to be adjusted."
      return
    end

    puts "C> \t- Refreshing sizes for #{how_many} tasks (in background)..."
    BackgroundActivity::UpdateTaskWorkdirSize.setup!( local_tasks_not_sized.pluck(:id) )

  end



  def self.a090_check_for_spurious_task_workdirs #:nodoc:

    #-----------------------------------------------------------------------------
    puts "C> Trying to see if there are any spurious task work directories..."
    #-----------------------------------------------------------------------------

    myself        = RemoteResource.current_resource
    gridshare_dir = myself.cms_shared_dir

    if gridshare_dir.blank? || ! Dir.exists?(gridshare_dir)
      puts "C> \t- SKIPPING! No global task work directory yet configured!"
      return
    end

    # The find command below has been tested on Linux and Mac OS X
    # It MUST generate exactly three levels deep so it can properly
    # infer the original task ID !
    dirlist = Dir.chdir(gridshare_dir) do
      IO.popen("find . -mindepth 3 -maxdepth 3 -type d -print","r") { |fh| fh.readlines rescue [] }
    end

    uids2path = {} # this is the main list of all tasks
    dirlist.each do |path|  # path should be  "./01/23/45\n"
      next unless path =~ /\A\.\/(\d+)\/(\d+)\/(\d+)\s*\z/ # make sure
      idstring = Regexp.last_match[1..3].join("")
      uids2path[idstring.to_i] = path.strip.sub(/\A\.\//,"") #  12345 => "01/23/45"
    end

    all_task_ids  = CbrainTask.where({}).ids
    spurious_ids  = uids2path.keys - all_task_ids

    if spurious_ids.empty?
      puts "C> \t- No spurious task work directories detected."
      return
    else
      puts "C> \t- There are #{spurious_ids.size} spurious task work directories. Notifying admin."
    end

    message = spurious_ids.collect { |id| "rm -rf #{uids2path[id]}" }.join("\n");
    Message.send_message(User.admin,
      :type          => :system,
      :header        => "Spurious task work directories found on '#{myself.name}'",
      :description   => "Some spurious task work directories were found.\n" +
                        "These correspond to tasks that no longer exist in the database.",
      :variable_text => "Bash commands to clean them:\n" +
                        "cd #{gridshare_dir.bash_escape}\n" +
                        "#{message}\n",
      :critical      => true,
      :send_email    => false
    ) rescue true

  end



  def self.a100_ensure_dp_cache_symlink_exists #:nodoc:

    myself        = RemoteResource.current_resource
    gridshare_dir = myself.cms_shared_dir
    cache_dir     = myself.dp_cache_dir

    return unless Dir.exists?(gridshare_dir) && Dir.exists?(cache_dir)

    #----------------------------------------------------------------------------
    puts "C> Making sure the grid share directory has a symlink to the data provider cache..."
    #----------------------------------------------------------------------------

    sym_path = "#{gridshare_dir}/#{DataProvider::DP_CACHE_SYML}"
    if File.symlink?(sym_path) && File.realpath(sym_path) == File.realpath(cache_dir)
      system "touch", "-h", sym_path.to_s, gridshare_dir.to_s
      return
    end

    File.unlink(sym_path) if File.exists?(sym_path)
    File.symlink(cache_dir, sym_path)

    puts "C> \t- '#{sym_path}' -> '#{cache_dir}'"

  end



  def self.a110_ensure_task_class_git_commits_cached #:nodoc:

    #----------------------------------------------------------------------------
    puts "C> Ensuring git commits for tasks classes are pre-cached..."
    #----------------------------------------------------------------------------

    myself = RemoteResource.current_resource

    ToolConfig.where(:bourreau_id => myself.id)
        .map {|tc| tc.cbrain_task_class rescue nil}
        .uniq
        .compact  # to remove the nil
        .each { |klass| klass.revision_info.self_update }
  end



  def self.z000_ensure_we_have_a_forwarded_ssh_agent #:nodoc:

    #----------------------------------------------------------------------------
    puts "C> Making sure the portal is forwarding a SSH agent to us..."
    #----------------------------------------------------------------------------

    agent = SshAgent.find_forwarded.try(:aliveness)
    if agent
      puts "C> \t- Found a forwarded agent on SOCK=#{agent.socket}"
      agent.apply
    else
      puts "C> \t- WARNING: no forwarded agent detected! Hope you exchanged all the SSH keys instead!"
      puts "C> \t- WARNING: this mode of operation is not really supported!"
    end

  end



  def self.z010_ensure_custom_bash_scripts_succeed #:nodoc:

    checker_dir = Rails.root + "boot_checks"
    return if ! File.directory? checker_dir.to_s

    #----------------------------------------------------------------------------
    puts "C> Running custom checker bash scripts..."
    #----------------------------------------------------------------------------

    scripts  = Dir.glob("#{checker_dir}/*.sh")
    if scripts.empty?
      puts "C> \t- Skipping, no scripts configured."
      return
    end

    scripts.sort.each do |fullpath|
      basename = Pathname.new(fullpath).basename
      puts "C> \t- Executing '#{basename}'..."
      system("bash",fullpath)
      status  = $? # a Process::Status object
      next if status.exitstatus == 0
      puts "C> \t- STOPPING BOOT SEQUENCE: script returned with status #{status.exitstatus}"
      raise "Script '#{basename}' exited with #{status.exitstatus}"
    end
  end



  def self.z020_start_background_activity_workers #:nodoc:

    #----------------------------------------------------------------------------
    puts "C> Starting Background Activity Workers..."
    #----------------------------------------------------------------------------

    if ENV['CBRAIN_NO_BACKGROUND_ACTIVITY_WORKER'].present? || Rails.env == 'test'
      puts "C> \t- NOT started as we are in test mode, or env variable CBRAIN_NO_BACKGROUND_ACTIVITY_WORKER is set."
      return
    end

    myself = RemoteResource.current_resource
    myself.send_command_start_bac_workers # will be a local message, not network

  end

end

