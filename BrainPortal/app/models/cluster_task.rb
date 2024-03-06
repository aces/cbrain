
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

#Abstract model representing a job running on a cluster. This is the core class for
#launching Slurm/GridEngine/PBS/MOAB/UNIX jobs (etc) using Scir.
#
#=Attributes:
#[<b>user_id</b>] The id of the user who requested this task.
#[<b>bourreau_id</b>] The id of the Bourreau on which the task is running.
#[<b>status</b>] The status of the current task.
#[<b>params</b>] A hash of the parameters sent in the job request from BrainPortal.
#[<b>cluster_jobid</b>] The job id of the running task. This id is a string
#                       specific to the cluster management system configured for the
#                       bourreau, and has no meaning outside of there.
#[<b>cluster_workdir</b>] The work directory in which the task is running. Like the
#                         *cluster_jobid*, this directory has no meaning outside
#                         of the context of the host where the Bourreau is running.
#[<b>share_wd_tid</b>] The task id of another task; if set, the current task will
#                      be configured to execute in the same +cluster_workdir+.
#[<b>prerequisites</b>] A hash table providing information about what other
#                       tasks the current task depend on.
#[<b>log</b>] A log of task's progress.
#
#<b>ClusterTask objects should not be instantiated directly.</b> Instead, subclasses of ClusterTask should be created to
#represent requests for specific processing tasks.
#
#= Creating a ClusterTask subclass
#Subclasses of ClusterTask will have to override the following methods to function properly:
#[<b>setup</b>] Perform any preparatory steps before launching the job (e.g. syncing files).
#[*cluster_commands*] Returns an array of the bash commands to be run by the job.
#[*save_results*] Perform any finalization steps after the job is run (e.g. saving result files).
#
#Note that all these methods can access request parameters through the hash in the +params+
#attribute.
#
#A generator script has been written to simplify the creation of ClusterTask subclasses. To
#use it, simply go to the Bourreau application's base directory and run:
#  script/generate cluster_task <your_task_name>
#This will create a template for your task.
#
#Instructions in the files themselves will indicate how to integrate your task into the system.
class ClusterTask < CbrainTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include NumericalSubdirTree

  # The 'science' script is where the scientific commands
  # of the task are held. It is a bash script, where most
  # of the earlier commands are created from the ToolConfigs,
  # and the last commands are supplied by the cluster_commands()
  # method.
  #
  # These basenames get modified with suffixes appended to them.
  RUNTIME_INFO_BASENAME   = ".runtime_info"# appended: ".{name}.{run_id}.kv"
  SCIENCE_SCRIPT_BASENAME = ".science"     # appended: ".{name}.{run_id}.sh"
  SCIENCE_STDOUT_BASENAME = ".science.out" # appended: ".{name}.{run_id}"
  SCIENCE_STDERR_BASENAME = ".science.err" # appended: ".{name}.{run_id}"

  # The qsub script is a bash wrapper that executes the scientific script.
  # These basenames get modified with suffixes appended to them.
  QSUB_SCRIPT_BASENAME    = ".qsub"        # appended: ".{name}.{run_id}.sh"
  QSUB_STDOUT_BASENAME    = ".qsub.out"    # appended: ".{name}.{run_id}"
  QSUB_STDERR_BASENAME    = ".qsub.err"    # appended: ".{name}.{run_id}"

  before_destroy :before_destroy_terminate_and_rm_workdir
  validate       :task_is_proper_subclass

  # Resource usage tracking
  after_status_transition 'Queued', 'Data Ready',                  :track_resource_usage_cpu
  after_status_transition 'On CPU', 'Data Ready',                  :track_resource_usage_cpu
  after_status_transition '*', Regexp.new(FINAL_STATUS.join('|')), :track_resource_usage_final



  ##################################################################
  # Core Model Methods
  ##################################################################

  # Automatically register the task's version when new() is invoked.
  def initialize(arguments = {}) #:nodoc:
    res = super(arguments)
    self.record_cbraintask_revs(2)
    res
  end

  # Records the revision number of ClusterTask and the
  # revision number of the its specific subclass.
  def record_cbraintask_revs(caller_level=1) #:nodoc:
    baserev = ClusterTask::Revision_info
    subrev  = self.revision_info
    self.addlog("#{baserev.basename} rev. #{baserev.short_commit}", :caller_level => caller_level + 1)
    self.addlog("#{subrev.basename} rev. #{subrev.short_commit}",   :caller_level => caller_level + 1)
  end



  ##################################################################
  # Main User API Methods
  # setup(), cluster_commands() and save_results()
  ##################################################################

  # This needs to be redefined in a subclass.
  # Returning true means that everything went fine
  # during setup. Returning false or raising an
  # exception will mark the job with a final
  # status "Failed To Setup".
  def setup
    true
  end

  # This needs to be redefined in a subclass.
  # It should return an array of bash commands,
  # each array element being one line of the bash
  # script.
  def cluster_commands
    [ "true >/dev/null" ]
  end

  # This needs to be redefined in a subclass.
  # Returning true means that everything went fine
  # during result gathering. Returning false will mark
  # the job with a final status "Failed On Cluster".
  # Raising an exception will mark the job with
  # a final status "Failed To PostProcess".
  def save_results
    true
  end

  # This method can be redefined in a subclass;
  # it will be called by the framework to query
  # a task and get an estimate of how long the
  # task will run. This is used when submitting the
  # job on the cluster. The value returned by a
  # CbrainTask should be conservative and be reasonably
  # larger than the longest run expected, without being
  # overly excessive. The default value used by
  # the framework is 24.hours
  def job_walltime_estimate
    24.hours
  end



  ##################################################################
  # Main User API Methods
  # Error recovery and restarts
  ##################################################################

  # This needs to be redefined in a subclass.
  # This method must do what is necessary to figure out
  # why a task was in 'Failed To Setup' and fix things.
  # If it returns true, the task will be sent back to the
  # 'New' state. The run_number will stay the same.
  #
  # Note that including the module RecoverableTask
  # will provide a copy of this method that simply
  # returns true; this is useful if your setup()
  # method is naturally recoverable.
  def recover_from_setup_failure
    self.addlog("This task is not programmed for recovery.")
    false
  end

  # This needs to be redefined in a subclass.
  # This method must do what is necessary to figure out
  # why a task was in 'Failed On Cluser' and fix things.
  # If it returns true, the task will be restarted on
  # the cluster (with a new job ID) and returned to
  # stated 'Queued'. The run_number will stay the same.
  #
  # Note that including the module RecoverableTask
  # will provide a copy of this method that simply
  # returns true; this is useful if your bash commands
  # returned by cluster_commands() are naturally recoverable.
  def recover_from_cluster_failure
    self.addlog("This task is not programmed for recovery.")
    false
  end

  # This needs to be redefined in a subclass.
  # This method must do what is necessary to figure out
  # why a task was in 'Failed To PostProcess' and fix things.
  # If it returns true, the task will be sent back to the
  # 'Data Ready' state. The run_number will stay the same.
  #
  # Note that including the module RecoverableTask
  # will provide a copy of this method that simply
  # returns true; this is useful if your save_results()
  # method is naturally recoverable.
  def recover_from_post_processing_failure
    self.addlog("This task is not programmed for recovery.")
    false
  end

  # This needs to be redefined in a subclass.
  # This method must prepare the task's work directory
  # such that it can be restarted anew from the 'Setting
  # Up' state. If the method returns false, the task
  # cannot be restarted in this way. Note that the
  # run_number will be increased by one if a restart is
  # attempted.
  #
  # Note that including the module RestartableTask
  # will provide a copy of this method that simply
  # returns true; this is useful if your setup()
  # method is naturally restartable.
  def restart_at_setup
    self.addlog("This task is not programmed for restarts.")
    false
  end

  # This needs to be redefined in a subclass.
  # This method must prepare the task's work directory
  # such that it can be restarted anew from the 'Queued'
  # state. If the method returns false, the task
  # cannot be restarted in this way. Note that the
  # run_number will be increased by one if a restart is
  # attempted.
  #
  # Note that including the module RestartableTask
  # will provide a copy of this method that simply
  # returns true; this is useful if your bash commands
  # returned by cluster_commands() are naturally restartable.
  def restart_at_cluster
    self.addlog("This task is not programmed for restarts.")
    false
  end

  # This needs to be redefined in a subclass.
  # This method must prepare the task's work directory
  # such that it can be restarted anew from the 'Post'
  # Processing' state. If the method returns false, the task
  # cannot be restarted in this way. Note that the
  # run_number will be increased by one if a restart is
  # attempted.
  #
  # Note that including the module RestartableTask
  # will provide a copy of this method that simply
  # returns true; this is useful if your save_results()
  # method is naturally restartable.
  def restart_at_post_processing
    self.addlog("This task is not programmed for restarts.")
    false
  end



  ##################################################################
  # Utility Methods For CbrainTask:ClusterTask Developers
  ##################################################################

  # Utility method for developers to use while writing
  # a task's setup() or save_results() methods.
  # This method creates a subdirectory in your work directory.
  # To make it practical when writing restartable or recoverable
  # code, it will not complain of the directory already exists,
  # unlike Dir.mkdir() which raises an exception.
  # The +relpath+ MUST be relative and the current directory MUST
  # be the task's work directory.
  def safe_mkdir(relpath,mode=0700)
    relpath = relpath.to_s
    cb_error "Current directory is not the task's work directory?" unless self.we_are_in_workdir
    cb_error "New directory argument must be a relative path." if
      relpath.blank? || relpath =~ /\A\//
    Dir.mkdir(relpath,mode) unless File.directory?(relpath)
  end

  # Utility method for developers to use while writing
  # a task's setup() or save_results() methods.
  # This method creates a symbolic link in your work directory.
  # To make it practical when writing restartable or recoverable
  # code, it will silently replace a symbolic link that already
  # exists instead of raising an exception like File.symlink().
  # The +relpath+ MUST be relative and the current directory MUST
  # be the task's work directory. The +original_entry+ can be any
  # string, whether it matches an existing path or not.
  def safe_symlink(original_entry,relpath)
    original_entry = original_entry.to_s
    relpath        = relpath.to_s
    cb_error "Current directory is not the task's work directory?" unless self.we_are_in_workdir
    cb_error "New directory argument must be a relative path." if
      relpath.blank? || relpath =~ /\A\//
    File.unlink(relpath) if File.symlink?(relpath)
    File.symlink(original_entry,relpath)
  end

  # Utility method for developers to use while writing
  # a task's setup() or save_results() methods.
  # This method acts like the new() method of Userfile,
  # but if the attribute list match a file already
  # existing then it will return that file instead
  # of a new() entry. This is useful when writing
  # recoverable or restartable code that creates a
  # report or a result file, for instance.
  # +klass+ must be a class that is a subclass of
  # Userfile, and +attlist+ must be an attribute list
  # containing at the minimum :name and :data_provider_id.
  # The :user_id and :group_id default to the task's.
  def safe_userfile_find_or_new(klass,attlist)
    cb_error "Class for file must be a subclass of Userfile." unless klass < Userfile
    attlist = attlist.dup
    attlist[:data_provider_id] ||= self.results_data_provider_id.presence
    attlist[:data_provider_id] ||= Userfile.find(self.params[:interface_userfile_ids].first).data_provider_id
    cb_error "Attribute list missing a required attribute." if
      [ :name, :data_provider_id ].any? { |i| attlist[i].blank? } # minimal set!
    unless attlist.has_key?(:user_id)
      cb_error "Cannot assign user to file." unless self.user_id
      attlist[:user_id] = self.user_id
    end
    group_id_for_file = attlist.delete(:group_id) || self.group_id # is re-assigned later
    cb_error "Cannot assign group to file." unless group_id_for_file
    results = klass.where( attlist ).all
    if results.size == 1
      existing_userfile = results[0]
      existing_userfile.cache_is_newer # we assume we want to update the content, always
      existing_userfile.group_id = group_id_for_file # crush or reset group
      return existing_userfile
    end
    cb_error "Found more than one file that match attribute list: '#{attlist.inspect}'." if results.size > 1
    attlist[:group_id] = group_id_for_file
    return klass.new(attlist)
  end

  # Returns whether or not the specified userfile exists.
  # This is a utility method for developers to use in the creation of safe code,
  # when creating output files. Permits smarter searching by using default
  # values taken from the attributes of the task itself.
  # One should at least specify the :name and :data_provider_id attributes,
  # but the latter is given a default value if not.
  def userfile_exists(klass,attlist)
    # Add default provider id
    attlist = attlist.dup
    attlist[:data_provider_id] ||= self.results_data_provider_id.presence
    attlist[:data_provider_id] ||= Userfile.find(self.params[:interface_userfile_ids].first).data_provider_id
    # Checks input type and attribute list is appropriate
    cb_error "Class for file must be a subclass of Userfile." unless klass < Userfile
    cb_error "Attribute list missing a required attribute." if
      [ :name, :data_provider_id ].any? { |i| attlist[i].blank? }
    # Fetch file
    results = klass.where( attlist ).all
    # Return whether we found one or not
    return results.count > 0
  end


  def we_are_in_workdir #:nodoc:
    full = self.full_cluster_workdir
    return false if full.blank?
    cur_dir = Dir.getwd
    Dir.chdir(full) do  # We need to do this in case the workdir goes through symlinks...
      return false if cur_dir != Dir.getwd
    end
    true
  end

  # Make a given +userfile+ available to the task
  # for processing at +file_path+, which is a relative
  # path inside the work directory of the task.
  # For example, to access the userfile with ID 6 at
  # <workdir>/mincfiles/input.mnc, do:
  #
  #     make_available(6, "mincfiles/input.mnc")
  #
  # If +file_path+ ends with a slash (/), the file's name
  # will be appended to form a valid file path:
  #
  #     make_available(6, "mincfiles/")
  #
  # will make userfile with ID 6 available at
  # <workdir>/mincfiles/<name of userfile with ID 6>
  #
  # +userfile+ can either be an ID or a Userfile
  # object. Note that just like safe_symlink, this method
  # will silently replace an existing symlink at +file_path+
  #
  # In the case where +userfile+ is a FileCollection, an optional
  # +userfile_sub_path+ can be provided to specify that the
  # symlink will point not to the +userfile+ itself, but to
  # a relative path in it. E.g. if userfile ID 99 points
  # to a FileCollection named "Abcd" with content:
  #
  #   Abcd/hello.txt
  #   Abcd/subdir/goodbye.txt
  #
  # then
  #
  #     make_available(99, "mygoodbye.txt", "subdir/goodbye.txt")
  #
  # will create a link 'mygoodbye.txt' that points deeper in the
  # directory structure.
  #
  # If start_dir is specified, it changes the root file location
  # from which the symlink's relative path to the dp_cache is
  # computed. This is useful for containerized tasks that have mounted
  # to a location different than the original task directory.
  def make_available(userfile, file_path, userfile_sub_path = nil, start_dir = nil)
    cb_error "File path argument must be relative" if
      file_path.to_s.blank? || file_path.to_s =~ /\A\//

    # Determine starting dir for relative symlink target calculation
    base_dir = start_dir || self.full_cluster_workdir

    # Fetch and sync the requested userfile
    userfile = Userfile.find(userfile) unless userfile.is_a?(Userfile)

    # Detect if we're trying to access a userfile content that is
    # containerized in a singularity overlay.
    is_local = nil
    if self.tool_config
           .data_providers_with_overlays
           .map(&:id)
           .include? userfile.data_provider_id
      userfile_path = Pathname.new(userfile.provider_full_path) # path inside container
      is_local      = true
      self.addlog("Input file '#{userfile.name}' is on a local Singularity overlay")
    else
      userfile.sync_to_cache
      userfile_path  = Pathname.new(userfile.cache_full_path)
    end

    # Compute the final absolute path to the target file symlink
    file_path     = Pathname.new(file_path.to_s)
    file_path    += userfile.name if file_path.to_s.end_with?("/")
    full_path     = Pathname.new(base_dir) + file_path

    # Pathname objects for the userfile and bourreau directories
    workdir_path   = Pathname.new(self.cluster_shared_dir)
    dp_cache_path  = Pathname.new(RemoteResource.current_resource.dp_cache_dir)

    # Pathname for the target value of the symlink with subpath
    userfile_path += Pathname.new(userfile_sub_path) if userfile_sub_path.to_s.present?

    # Try to figure out if the DataProvider of userfile is local, or remote.
    # SmartDataProviders supply the real implementation under a real_provider method;
    # other providers don't have that.
    if is_local.nil?
      userfile_real_dp = userfile.data_provider.real_provider rescue userfile.data_provider
      is_local = userfile_real_dp.is_a?(LocalDataProvider)
      self.addlog("Input file '#{userfile.name}' is on a local provider")  if   is_local
      self.addlog("Input file '#{userfile.name}' is on a remote provider") if ! is_local
    end

    # Files on local data providers are symlinked directly
    if is_local
      target = userfile_path # full path to filesystem location of local DP
    else
      # Figure out the two parts of the new symlink target; from file_path to
      # the DP cache symlink, and from the DP symlink to the userfile
      to_dp_syml    = workdir_path.relative_path_from(full_path.dirname) + DataProvider::DP_CACHE_SYML
      to_cached     = userfile_path.relative_path_from(dp_cache_path)
      target        = to_dp_syml + to_cached
    end

    # Make sure the directory exists and there is no symlink already there
    # Not done when the start_dir is specified because generally the path should
    # not exist outside the container (and we will not have permission to make it).
    unless start_dir
      FileUtils.mkpath(full_path.dirname) unless Dir.exists?(full_path.dirname)
      File.unlink(full_path) if File.symlink?(full_path.to_s) # potential race condition here
    end

    # Create the symlink
    Dir.chdir(self.full_cluster_workdir) do
      # Do nothing is symlink already exists with proper value.
      # If there is something not a symlink in the way, or a symlink with a different
      # value, the symlink() method will crash, which is what we want to
      # catch the error in the situation.
      unless File.symlink?(file_path.to_s) && File.readlink(file_path.to_s) == target.to_s
        File.symlink(target.to_s, file_path.to_s)
      end
    end

    true
  end

  # Returns true if +path+ points to a file or
  # directory that is inside the work directory
  # of the task. +path+ can be absolute or relative.
  # This method assumes the current directory of
  # the task's work directory, which is usually
  # the common case for invoking it.
  def path_is_in_workdir?(path) #:nodoc:
    workdir = self.full_cluster_workdir
    return false unless workdir.present? && File.directory?(workdir)
    return false unless File.exists?(path)
    path = Pathname.new(path).realdirpath rescue nil
    return false unless path
    wdpath   = Pathname.new(workdir)
    rel_path = path.relative_path_from(wdpath) rescue nil
    return false if rel_path.to_s.blank? || rel_path.to_s =~ /\A\.\./ # if it starts with ".." it means we go out of the workdir!
    true
  end

  # This method takes an array of +userfiles+ (or a single one)
  # and add a log entry to each userfile identifying that
  # it was processed by the current task. An optional
  # comment can be appended to the message.
  def addlog_to_userfiles_processed(userfiles, comment = "", caller_level=0)
    userfiles = [ userfiles ] unless userfiles.is_a?(Array)
    myname   = self.fullname
    mylink   = "/tasks/#{self.id}"  # can't use show_task_path() on Bourreau side
    mymarkup = "[[#{myname}][#{mylink}]]"
    userfiles.each do |u|
      next unless u.is_a?(Userfile) && u.id
      u.addlog_context(self,"Processed by task #{mymarkup} #{comment}",3+caller_level)
    end
  end

  # This method takes an array of +userfiles+ (or a single one)
  # and add a log entry to each userfile identifying that
  # it was created by the current task. An optional
  # comment can be appended to the message.
  def addlog_to_userfiles_created(userfiles, comment = "", caller_level=0)
    userfiles = [ userfiles ] unless userfiles.is_a?(Array)
    myname   = self.fullname
    mylink   = "/tasks/#{self.id}" # can't use show_task_path() on Bourreau side
    mymarkup = "[[#{myname}][#{mylink}]]"
    userfiles.each do |u|
      next unless u.is_a?(Userfile) && u.id
      u.addlog_context(self,"Created/updated by #{mymarkup} #{comment}",3+caller_level)
    end
  end

  # This method takes an array of userfiles +creatorlist+ (or a single one),
  # another array of userfiles +createdlist+ (or a single one)
  # and records for each created file what were the creators, and for
  # each creator file what files were created, along with a link
  # to the task itself. An optional comment can be appended to the header message.
  def addlog_to_userfiles_these_created_these(creatorlist, createdlist, comment="", caller_level=0)

    # Two lists of userfiles. Make sure their contents are OK.
    creatorlist = Array(creatorlist).select { |u| u.is_a?(Userfile) && u.id }
    createdlist = Array(createdlist).select { |u| u.is_a?(Userfile) && u.id }

    # Info about myself, a task.
    myname   = self.fullname
    mylink   = "/tasks/#{self.id}"  # can't use show_task_path() on Bourreau side
    mymarkup = "[[#{myname}][#{mylink}]]"

    # Arrays of markups. Can't use userfile_path() on Bourreau side, so path is hardcoded
    creatorMarkups = creatorlist.map { |creator| "[[#{creator.name}][/userfiles/#{creator.id}]]" }
    createdMarkups = createdlist.map { |created| "[[#{created.name}][/userfiles/#{created.id}]]" }

    # Add an entry to each creator files, listing created files
    creatorlist.each do |creator|
      if createdlist.size == 1 # a common case; create shorter log entry then.
        creator.addlog_context(self, "Used by task #{mymarkup} to create #{createdMarkups[0]}. #{comment}", 4+caller_level)
      else
        creator.addlog_context(self, "Used by task #{mymarkup}, list of #{createdlist.size} created files follow. #{comment}", 4+caller_level)
        createdMarkups.each_slice(5).each do |files_4|
          creator.addlog(files_4.join(", "))
        end
      end
    end # creators done

    # Add an entry to each created files, listing creators
    createdlist.each do |created|
      if creatorlist.size == 1 # a common case; create shorter log entry then.
        created.addlog_context(self, "Created/updated by task #{mymarkup} from file #{creatorMarkups[0]}. #{comment}", 4+caller_level)
      else
        created.addlog_context(self, "Created/updated by task #{mymarkup}, list of #{creatorlist.size} used files follow. #{comment}", 4+caller_level)
        creatorMarkups.each_slice(5).each do |files_4|
          created.addlog(files_4.join(", "))
        end
      end
    end # created done

    true # well it's less costly to return than e^pi
  end

  # This method is the equivalent of running a system() call
  # with the output captured, but where the supplied command
  # will be executed within the full environment context defined
  # for the task (that is, environment variables AND bash
  # prologues will have been executed before the +command+ ).
  # The +command+ itself can be a multi line script if needed,
  # as it will be appended to a longer script that wil be passed
  # to bash. The method returns an array of two strings,
  # the STDOUT and STDERR produced by the internally
  # generated script.
  #
  # Note that the script is executed in the task's work
  # directory, even though its text is stored in "/tmp".
  def tool_config_system(command)

    cb_error "Current directory is not the task's work directory?" unless self.we_are_in_workdir

    # Defines tmp file paths
    scriptfile = "/tmp/tool_script.#{$$}.#{Time.now.to_i}"
    outfile    = "#{scriptfile}.out"
    errfile    = "#{scriptfile}.err"

    # Find the tool configuration in effect
    # We need three objects, each can be nil.
    bourreau_glob_config = self.bourreau.global_tool_config
    tool_glob_config     = self.tool.global_tool_config
    tool_config          = self.tool_config

    # Build script
    script  = ""
    # flag to guaranty propagation of env variables to the singularity/apptainer
    # as far I know only needed to reverse effect of --cleanenv option, and otherwise all vars are copied to the container
    # yet potentially more cases may be identified
    propagate = self.use_singularity?
    # Add prologues in specialization order
    script += bourreau_glob_config.to_bash_prologue propagate if bourreau_glob_config
    script += tool_glob_config.to_bash_prologue     propagate if tool_glob_config
    script += tool_config.to_bash_prologue          propagate if tool_config
    # Add CBRAIN special inits
    script += self.supplemental_cbrain_tool_config_init
    # Add the command
    script += "\n\n" + command + "\n\n"
    # Add epilogues in reverse order
    script += tool_config.to_bash_epilogue          if tool_config
    script += tool_glob_config.to_bash_epilogue     if tool_glob_config
    script += bourreau_glob_config.to_bash_epilogue if bourreau_glob_config

    # Write the temp script
    File.open(scriptfile,"w") { |fh| fh.write(script) }

    # Execute and capture
    system("/bin/bash #{scriptfile.bash_escape} </dev/null >#{outfile.bash_escape} 2>#{errfile.bash_escape}")
    out = File.read(outfile) rescue ""
    err = File.read(errfile) rescue ""
    return [ out, err ]

  ensure
    File.unlink(scriptfile) rescue true
    File.unlink(outfile)    rescue true
    File.unlink(errfile)    rescue true
  end

  # Used to add some more initialization code specific to
  # the CBRAIN system itself, after all other tool_config
  # initializations. Returns a few lines of BASH code as
  # a single string. If overrriden in subclasses, make sure
  # to append the bash code to the one returned by super()!
  def supplemental_cbrain_tool_config_init #:nodoc:
    "\n" +
    "# CBRAIN Bourreau-side initializations\n" +
    "export PATH=#{(Rails.root.to_s + "/vendor/cbrain/bin").to_s.bash_escape}:\"$PATH\"\n"
  end



  ##################################################################
  # Main control methods (mainly called by the BourreauWorker)
  ##################################################################

  # This is called only by a BourreauWorker once when the object is new.
  # A temporary, grid-aware working directory is created
  # for the job, and the task-specific setup() method is invoked in it.
  # Then the task's BASH commands are submitted to the cluster.
  def setup_and_submit_job

    cb_error "Expected Task object to be in 'Setting Up' state." unless
      self.status == 'Setting Up'
    return false if self.workdir_archived?

    begin
      self.addlog("Setting Up.")
      self.record_cbraintask_revs
      self.make_cluster_workdir
      self.apply_tool_config_environment do
        Dir.chdir(self.full_cluster_workdir) do
          setup_success = self.meta[:submit_without_setup] || self.setup
          if ! setup_success  # as defined by subclass
            self.addlog("Failed to setup: 'false' returned by setup().")
            self.status_transition(self.status, "Failed To Setup")
          elsif ! self.submit_cluster_job
            self.addlog("Failed to start: 'false' returned by submit_cluster_job().")
            self.status_transition(self.status, "Failed To Setup")
          else
            self.addlog("Setup and submit process successful.")
            self.track_usage_of_input_files_after_setup
            # the status is moving forward at its own pace now
          end
          self.meta[:submit_without_setup] = nil # reset special skip
        end
      end
      self.update_size_of_cluster_workdir
    rescue => e
      self.meta[:submit_without_setup] = nil # reset special skip
      self.addlog_exception(e,"Exception raised while setting up:")
      self.status_transition(self.status, "Failed To Setup")
    end

    self.save
  end

  # This method must returns true if a task is at status 'Data Ready' and
  # other properties allow it to enter post processing. It will be
  # called by a BourreauWorker. The default behavior is to make a special check
  # in the work directory to make sure the qsub_stdout_basename file
  # is present if the task's updated_at timestamp is within a short
  # window of time (hardcoded at 60 seconds here). This check is necessary
  # because on some clusters, a job can be finished and yet the captured
  # output file of the job might take up to a minute to appear in the
  # work directory. If the BourreauWorker started to post process the task during
  # the period when the file isn't there, it would mark it as 'Failed On Cluster'.
  #
  # This method can be overrided in particular subclasses, but it is highly
  # recommended to at least invoke the super method first, e.g.
  #
  #   # In a subclass
  #   def ready_to_post_process?
  #     return false unless super
  #     #more custom checks here
  #   end
  def ready_to_post_process?
    # Basic properties of the task
    return false unless self.status     == 'Data Ready'
    return true  if     self.updated_at <  1.minute.ago # window elapsed; old tasks are considered a 'go'

    # Check for qsub stdout file presence
    stdout_file = (Pathname.new(self.full_cluster_workdir) + self.qsub_stdout_basename).to_s
    return true  if     File.exists?(stdout_file) && File.size(stdout_file) > 0

    # Well, at this point the task is super recently updated
    # and the stdout file is not yet seen, so we postpone post processing.
    message = "PostProcessing delayed: no stdout file yet available."
    self.addlog(message) unless self.getlog[message]
    false
  end

  # This is called by a BourreauWorker to finish processing a job that has
  # successfully run on the cluster. The main purpose
  # is to call the subclass' supplied save_result() method
  # then cleanup the temporary grid-aware directory.
  def post_process

    cb_error "Expected Task object to be in 'Post Processing' state." unless
      self.status == 'Post Processing'
    return false if self.workdir_archived?

    # This used to be run in background, but now that
    # we have a worker subprocess, we no longer need
    # to have a spawn occur here.
    begin
      self.addlog("Starting post processing.")
      self.record_cbraintask_revs
      self.update_size_of_cluster_workdir
      self.apply_tool_config_environment do
        saveok = false
        Dir.chdir(self.full_cluster_workdir) do
          # Verifies the captured output contains the proper
          # token line 'CBRAIN Task Exiting' as created by qsub wrapper.
          # If a special meta keyword :no_end_keyword_check, we don't verify it;
          # this happens usually after a "Restart PostProcess".
          saveok = self.meta[:no_end_keyword_check].present? || check_task_ending_keyword(qsub_stdout_basename)
          self.addlog("Could not find completion keywords at end of output. Process might have been interrupted.") if ! saveok
          # Call the subclass-provided save_results()
          saveok = saveok && self.save_results
          self.meta[:no_end_keyword_check] = nil
        end
        if ! saveok
          self.status_transition(self.status, "Failed On Cluster")
          self.addlog("Data processing failed on the cluster.")
        else
          self.update_size_of_cluster_workdir # callbacks and modules might have cleaned up the files by now
          self.addlog("Post processing completed.")
          self.status_transition(self.status, "Completed")
        end
      end
    rescue => e
      self.addlog_exception(e,"Exception raised while post processing results:")
      self.status_transition(self.status, "Failed To PostProcess")
    end

    self.save
  end

  # Possible returned status values:
  # [<b>New</b>] The task is new and not yet set up.
  # [<b>Standby</b>] The task just exists; getting out of this state is up to the process which set it thus.
  # [<b>Setting Up</b>] The task is in its asynchronous 'setup' state.
  # [<b>Configured</b>] The task has been set up but NOT launched on cluster.
  # [<b>Failed *</b>]  (To Setup, On Cluster, etc) The task failed at some stage.
  # [<b>Queued</b>] The task is queued.
  # [<b>On CPU</b>] The task is underway.
  # [<b>Data Ready</b>] The task has been completed, but data has not been sent back to BrainPortal.
  # [<b>Post Processing</b>] The task is sending back its data to the BrainPortal.
  # [<b>Completed</b>] The task has been completed, and data has been sent back to BrainPortal.
  # [<b>On Hold</b>] The task is queued, but should not be sent to the CPU even if it's ready.
  # [<b>Suspended</b>] The has been suspended while it was on CPU.
  # [<b>Terminated</b>] The task has been terminated by request of the user.
  #
  # The values are determined by BOTH the current state returned by
  # the cluster and the previously recorded value of status().
  # Some other values are reached by calling methods, such as
  # post_process() which changes <b>Data Ready</b> to <b>Completed</b>.
  def update_status

    ar_status = self.status
    if ar_status.blank?
      cb_error "Unknown blank status obtained from CbrainTask ActiveRecord #{self.id}."
    end

    return ar_status if self.workdir_archived?

    # The list below contains states that are either final
    # or are are moved to other states using other mechanism
    # than a check with the cluster's state. For instance:
    # - "Data Ready" which can be moved to "Post Processing"
    #    through the method call save_results()
    # - "Post Processing" which will be moved to "Completed"
    #    through the method call save_results()
    return ar_status if ar_status.match(/^(Duplicated|Standby|New|Setting Up|Configured|Failed.*|Data Ready|Terminated|Completed|Post Processing|Recover|Restart|Preset)$/)

    # This is the expensive call, the one that queries the cluster.
    clusterstatus = self.cluster_status
    return self.status if clusterstatus.blank?  # this means the cluster can't tell us, for some reason.
    #self.addlog("ar_status is #{ar_status} ; cluster stat is #{clusterstatus}")

    # Steady states for cluster jobs
    if clusterstatus.match(/^(On CPU|Suspended|On Hold|Queued)$/)
      self.status_transition(ar_status,clusterstatus) if ar_status != clusterstatus # try to update; ignore errors.
      return self.status
    end

    # At this point here then, clusterstatus == "Does Not Exist"
    if ar_status.match(/^(On CPU|Suspended|On Hold|Queued)$/)
      self.status_transition(self.status,"Data Ready") # try to update; ignore errors.
      return self.status
    end

    cb_error "Cluster job finished with unknown Active Record status #{ar_status} and Cluster status #{clusterstatus}"
  end



  ##################################################################
  # Task Control Methods
  # (hold, suspend, terminate, etc etc)
  ##################################################################

  # Terminate the task (if it's currently in an appropriate state.)
  def terminate
    cur_status = self.status
    return false if self.workdir_archived?

    # Cluster job termination
    if cur_status.match(/^(On CPU|On Hold|Suspended|Queued)$/)
      self.scir_session.terminate(self.cluster_jobid)
      return self.status_transition(cur_status,"Terminated")
    end

    # New tasks are simply marked as Terminated
    if cur_status =~ /^(New|Configured)$/
      return self.status_transition(cur_status,"Terminated")
    end

    # Stuck or lost jobs executing Ruby code
    if self.mark_as_failed_in_ruby
      self.addlog("Task is too old and stuck at '#{cur_status}'; status reset to '#{self.status}'")
      return self.save
    end

    # Otherwise, we don't do nothin'
    return false
  rescue
    false
  end

  # Suspend the task (if it's currently in an appropriate state.)
  def suspend
    return false unless self.status == "On CPU"
    return false if self.workdir_archived?
    begin
      self.scir_session.suspend(self.cluster_jobid)
      self.status_transition(self.status, "Suspended")
    rescue
      false
    end
  end

  # Resume processing the task if it was suspended.
  def resume
    return false if self.workdir_archived?
    begin
      return false unless self.status == "Suspended"
      self.scir_session.resume(self.cluster_jobid)
      self.status_transition(self.status, "On CPU")
    rescue
      false
    end
  end

  # Put the task on hold if it is currently queued.
  def hold
    return false unless self.status == "Queued"
    return false if self.workdir_archived?
    begin
      self.scir_session.hold(self.cluster_jobid)
      self.status_transition(self.status, "On Hold")
    rescue
      false
    end
  end

  # Release the task from state On Hold.
  def release
    return false if self.workdir_archived?
    begin
      return false unless self.status == "On Hold"
      self.scir_session.release(self.cluster_jobid)
      self.status_transition(self.status, "Queued")
    rescue
      false
    end
  end

  # Updates the task's status to one of the 'Failed' states if it has
  # been updated more than +timeout+ ago and seems to be stuck
  # in a 'Ruby' stage. Returns true if the task's status was changed to a
  # 'Failed' state, false or nil if the status is left unchanged.
  def mark_as_failed_in_ruby(timeout = 8.hours)
    return false unless self.updated_at < timeout.ago && CbrainTask::RUBY_STATUS.include?(self.status)
    case self.status
      when "Setting Up"
        self.status_transition(self.status, "Failed To Setup")
      when "Post Processing"
        self.status_transition(self.status, "Failed To PostProcess")
      when /(Recovering|Restarting) (\S+)/
        fromwhat = Regexp.last_match[2]
        if    fromwhat == 'Setup'
          self.status_transition(self.status, "Failed To Setup")
        elsif fromwhat == 'Cluster'
          self.status_transition(self.status, "Failed On Cluster")
        elsif fromwhat == 'PostProcess'
          self.status_transition(self.status, "Failed To PostProcess")
        end
    end
  end


  ##################################################################
  # Methods For Recovering From Failed Tasks
  # Methods For Restarting Completed Tasks
  ##################################################################

  # This triggers the recovery mechanism for all Failed tasks.
  # This simply sets a special value in the 'status' field
  # that will be handled by the BourreauWorker.
  def recover
    return false if self.workdir_archived?
    curstat = self.status
    if curstat =~ /^Failed (Setup|PostProcess) Prerequisites$/
      failed_where = Regexp.last_match[1]
      self.addlog("Resetting prerequisites checking for '#{failed_where}'.")
      self.status_transition(self.status, "New")        if failed_where == "Setup"
      self.status_transition(self.status, "Data Ready") if failed_where == "PostProcess"
      return self.save
    end
    begin
      return false unless curstat =~ /^Failed (To Setup|On Cluster|To PostProcess)$/
      failedwhen = Regexp.last_match[1]
      self.addlog("Scheduling recovery from '#{curstat}'.")
      self.status_transition(self.status, "Recover Setup")       if failedwhen == "To Setup"
      self.status_transition(self.status, "Recover Cluster")     if failedwhen == "On Cluster"
      self.status_transition(self.status, "Recover PostProcess") if failedwhen == "To PostProcess"
      return self.save
    rescue
      false
    end
  end

  # This triggers the restart mechanism for all Completed tasks.
  # This simply sets a special value in the 'status' field
  # that will be handled by the BourreauWorker. The +atwhat+
  # argument must be exactly one of "Setup", "Cluster" or "PostProcess".
  def restart(atwhat = "Setup")
    return false if self.workdir_archived?
    begin
      return false unless self.status =~ /Completed|Terminated|Duplicated/
      return false unless atwhat =~ /^(Setup|Cluster|PostProcess)$/
      atwhat = "Setup" if self.status =~ /Terminated|Duplicated/ # forced
      self.addlog("Scheduling restart at '#{atwhat}'.")
      return self.status_transition(self.status, "Restart #{atwhat}") # will be handled by worker
    rescue
      false
    end
  end



  ##################################################################
  # Prerequisites Fulfillment Evaluation Methods
  ##################################################################

  # Returns a keyword indicating how the task's prerequisites
  # are satisfied; the argument +for_state+ indicates which of two
  # possible future transitions to check for: :for_setup or
  # :for_post_processing. This method is mostly used by the
  # BourreauWorker code, for deciding whether or not the time
  # as come to send the task to the cluster or to post process it.
  # The method returns three possible keywords:
  #
  # [[:go]] All prerequisites are satisfied.
  # [[:wait]] Some prerequisites are not yet satisfied.
  # [[:fail]] Some prerequisites have failed and thus at
  #           this point the task can never proceed.
  def prerequisites_fulfilled?(for_state)
    return :fail if self.workdir_archived?
    allprereqs = self.prerequisites    || {}
    prereqs    = allprereqs[for_state] || {}
    return :go if prereqs.empty?
    final_action = :go
    prereqs.keys.each do |t_taskid|  # taskid is a string like "T62"
      cb_error "Invalid prereq key '#{t_taskid}'." unless t_taskid =~ /\AT(\d+)\z/
      task_id = Regexp.last_match[1].to_i
      cb_notice "Task depends on itself!" if task_id == self.id # Cannot depend on yourself!!!
      task = CbrainTask.find(task_id) rescue nil
      cb_error "Could not find task '#{task_id}'" unless task
      needed_state   = prereqs[t_taskid] # one of "Queued" "Data Ready" "Completed" or "Fail"
      covered_states = PREREQS_STATES_COVERED_BY[needed_state]
      cb_error "Could not found coverage list for '#{needed_state}'" unless covered_states
      action = covered_states[task.status] || :fail
      cb_notice "Task '#{task.bname_tid}' is in state '#{task.status}' " +
                "while we wanted it in '#{needed_state}'." if action == :fail
      cb_error "Unknown action entry '#{action}' in prereq table? " +
               "Needed=#{needed_state} Task=#{task.bname_tid} in '#{task.status}'." unless action == :go || action == :wait
      final_action = :wait if action == :wait
      # we still need to check the rest of the tasks for :fail, so we loop back here.
    end
    return final_action # one of :go if ALL are :go, :wait if there is at least one :wait
  rescue CbrainNotice => e
    self.addlog("Prerequisite Check Failure: #{e.message}")
    self.save
    return :fail
  rescue CbrainError => e
    self.addlog("Prerequisite Check CBRAIN Error: #{e.message}")
    self.save
    return :fail
  rescue => e
    self.addlog_exception(e,"Prerequisite Check Exception:")
    self.save
    return :fail
  end



  ##################################################################
  # Cluster Job's STDOUT And STDERR Files Methods
  ##################################################################

  # Returns the basename of the script which contains
  # the scientific script itself, as build by the programmer in
  # is cluster_commands() method.
  def science_script_basename(run_number=nil)
    "#{SCIENCE_SCRIPT_BASENAME}.#{self.name}.#{self.run_id(run_number)}.sh"
  end

  # Returns the basename of the runtime info output capture file
  def runtime_info_basename(run_number=nil) #:nodoc:
    "#{RUNTIME_INFO_BASENAME}.#{self.name}.#{self.run_id(run_number)}.kv"
  end

  # Returns a basename for the QSUB script for the task.
  # This is not a full path, just a filename relative to the work directory.
  # The file itself is not guaranteed to exist.
  def qsub_script_basename(run_number=nil)
    "#{QSUB_SCRIPT_BASENAME}.#{self.name}.#{self.run_id(run_number)}.sh"
  end

  # Returns the basename for the QSUB standard output capture file for the task.
  # This is not a full path, just a filename relative to the work directory.
  # The file itself is not guaranteed to exist.
  def qsub_stdout_basename(run_number=nil) #:nodoc:
    "#{QSUB_STDOUT_BASENAME}.#{self.name}.#{self.run_id(run_number)}"
  end

  # Returns the basename for the QSUB standard error capture file for the task.
  # This is not a full path, just a filename relative to the work directory.
  # The file itself is not guaranteed to exist.
  def qsub_stderr_basename(run_number=nil) #:nodoc:
    "#{QSUB_STDERR_BASENAME}.#{self.name}.#{self.run_id(run_number)}"
  end

  private

  # Returns the basename of the captured standard output of
  # the scientific script.
  def science_stdout_basename(run_number=nil) #:nodoc:
    "#{SCIENCE_STDOUT_BASENAME}.#{self.name}.#{self.run_id(run_number)}"
  end

  # Returns the basename of the captured standard error of
  # the scientific script.
  def science_stderr_basename(run_number=nil) #:nodoc:
    "#{SCIENCE_STDERR_BASENAME}.#{self.name}.#{self.run_id(run_number)}"
  end

  # Given two basenames for two files, will combine them into a
  # a single report; the report will be the content of the
  # first file  where the token +__CBRAIN_CAPTURE_PLACEHOLDER__+
  # will be replaced by the content of the second file. The
  # new report is saved in a file with a name set to a modified version
  # of the name of the first file, "qsub_outerr-combined".
  #
  # The method returns that filename. If the combined report already exists,
  # the method just returns the filename, it will not be recreated.
  #
  # If the first file doesn't exist or is not complete (the content must
  # end with the line "CBRAIN Task Exiting") then the filename returned
  # is just the second file in argument, +science_outerr+ ; this means
  # that while a task is running, for instance, this method will still
  # return the output as it is being created.
  #
  # For this method to work properly, the CWD must be set to the
  # task's work directory.
  def find_or_create_combined_file(qsub_outerr, science_outerr) #:nodoc:
    cb_error "Current directory is not the task's work directory?" unless self.we_are_in_workdir

    # Report already prepared? Just return its basename
    combined_file = "#{qsub_outerr}-combined"
    return combined_file  if File.exists?(combined_file)

    # Task outputs incomplete? Point to science output captured
    return science_outerr if ! File.exists?(qsub_outerr)
    qsub_content = check_content_substitution_keyword(qsub_outerr) # returns nil unless content contains "__CBRAIN_CAPTURE_PLACEHOLDER__"
    return science_outerr if qsub_content.blank?

    # Create combined report
    science_content = File.read(science_outerr) rescue "(Processing content blank or unreadable)" # can be big but generally not to much
    qsub_content.sub!('__CBRAIN_CAPTURE_PLACEHOLDER__',science_content)
    File.open("#{combined_file}-tmp#{Process.pid}","w") { |fh| fh.write(qsub_content) }
    File.rename("#{combined_file}-tmp#{Process.pid}", combined_file) # atomicity for the win
    combined_file
  end

  # Checks that the content of some output file properly
  # has the keyword "CBRAIN Task Exiting".
  # Returns the file's content if it's true, otherwise returns nil
  def check_task_ending_keyword(basename)
    return nil unless File.exists?(basename)
    content = File.read(basename)
    return nil if content !~ /CBRAIN Task Exiting/
    content
  end

  # Returns the values of the 'times' command
  # we insert in the qsub wrapper script. Returns
  # nil if the values can't be parsed out.
  #
  #   CBRAIN Task Starting At 1567533649 : 2019-09-03 14:00:49
  #   __CBRAIN_CAPTURE_PLACEHOLDER__
  #   CBRAIN Task Ending With Status 0 After 91844 seconds, at 1567625493 : 2019-09-04 15:31:33
  #
  #   CBRAIN Task CPU Times Start
  #   0m0.015s 0m0.024s
  #   1516m58.086s 9m50.590s
  #   CBRAIN Task CPU Times End
  #   CBRAIN Task Exiting
  def extract_cpu_times_from_qsub_wrapper(filename)
    return nil unless File.exists?(filename.to_s)
    content = File.read(filename.to_s).tr("\n"," ")
    return nil if content !~
       /CBRAIN\sTask\sEnding\sWith\sStatus.*After\s(\d+)\sseconds
        .*
        CBRAIN\sTask\sCPU\sTimes\sStart
        \s+
        (\d+)m([\d\.]+)s  \s+  (\d+)m([\d\.]+)s  \s*
        (\d+)m([\d\.]+)s  \s+  (\d+)m([\d\.]+)s  \s*
        \s+
        CBRAIN\sTask\sCPU\sTimes\sEnd
       /x

    (walltime,
     user_loc_m, user_loc_s, syst_loc_m, syst_loc_s,
     user_tot_m, user_tot_s, syst_tot_m, syst_tot_s) = Regexp.last_match[1..8]

    user_loc = (user_loc_m.to_i * 60.0) + user_loc_s.to_f
    syst_loc = (syst_loc_m.to_i * 60.0) + syst_loc_s.to_f
    user_tot = (user_tot_m.to_i * 60.0) + user_tot_s.to_f
    syst_tot = (syst_tot_m.to_i * 60.0) + syst_tot_s.to_f

    {
      :walltime => walltime.to_i,
      :user_loc => user_loc, # cpu time of wrapper process only, not useful
      :syst_loc => syst_loc, # cpu time of wrapper process only, not useful
      :user_tot => user_tot, # cpu time of wrapper and subprocesses
      :syst_tot => syst_tot, # cpu time of wrapper and subprocesses
    }
  end

  # Checks that the content of some output file properly
  # has the keyword "__CBRAIN_CAPTURE_PLACEHOLDER__".
  # Returns the file's content if it's true, otherwise returns nil
  def check_content_substitution_keyword(basename)
    return nil unless File.exists?(basename)
    content = File.read(basename)
    return nil if content !~ /__CBRAIN_CAPTURE_PLACEHOLDER__/
    content
  end

  public

  # Returns the filename for the job's captured STDOUT.
  # Returns nil if the work directory has not yet been
  # created, or no longer exists. The file itself is not
  # guaranteed to exist, either. The returned value is
  # a full path.
  #
  # Because the output of the science script is redirected
  # to a file separately from the captured output of the qsub
  # script, this method will try to provide the path to a
  # combined file when possible (usually when the task is complete)
  # and otherwise will just return a path to the
  # science output file.
  def stdout_cluster_filename(run_number=nil)
    workdir = self.full_cluster_workdir
    return nil if workdir.blank?
    qsub_out_file    = qsub_stdout_basename(run_number)
    science_out_file = science_stdout_basename(run_number)
    combined_file    = Dir.chdir(workdir) { find_or_create_combined_file(qsub_out_file, science_out_file) }
    return (Pathname.new(workdir) + combined_file).to_s if combined_file.to_s.present?
    nil
  end

  # This method works just like stdout_cluster_filename() but provides
  # a path to the job's captured STDERR.
  def stderr_cluster_filename(run_number=nil)
    workdir = self.full_cluster_workdir
    return nil if workdir.blank?
    qsub_err_file    = qsub_stderr_basename(run_number)
    science_err_file = science_stderr_basename(run_number)
    combined_file    = Dir.chdir(workdir) { find_or_create_combined_file(qsub_err_file, science_err_file) }
    return (Pathname.new(workdir) + combined_file).to_s if combined_file.to_s.present?
    nil
  end

  # Read back the STDOUT and STDERR files for the job, and
  # store (part of) their contents in the task's object;
  # this is called explicitly only in the case when the
  # portal performs a 'show' request on a single task
  # otherwise it's too expensive to do it every time. The
  # pseudo attributes :cluster_stdout and :cluster_stderr
  # are not really part of the task's ActiveRecord model.
  def capture_job_out_err(run_number=nil,stdout_lim=2000,stderr_lim=2000)
     self.cluster_stdout = nil
     self.cluster_stderr = nil
     self.script_text    = nil
     self.runtime_info   = nil

     return if self.new_record? || self.workdir_archived?

     stdout_lim        ||= 2000
     stdout_lim          = stdout_lim.to_i
     stdout_lim          = 2000 if stdout_lim <= 100 || stdout_lim > 999999

     stderr_lim        ||= 2000
     stderr_lim          = stderr_lim.to_i
     stderr_lim          = 2000 if stderr_lim <= 100 || stderr_lim > 999999

     stdoutfile  = self.stdout_cluster_filename(run_number)
     stderrfile  = self.stderr_cluster_filename(run_number)
     scriptfile  = Pathname.new(self.full_cluster_workdir) + self.science_script_basename(run_number) rescue nil
     runtimefile = Pathname.new(self.full_cluster_workdir) + self.runtime_info_basename(run_number)   rescue nil

     if stdoutfile && File.exist?(stdoutfile)
       io = IO.popen("tail -#{stdout_lim} #{stdoutfile.to_s.bash_escape}","r")
       self.cluster_stdout = io.read
       io.close
     end

     if stderrfile && File.exist?(stderrfile)
       io = IO.popen("tail -#{stderr_lim} #{stderrfile.to_s.bash_escape}","r")
       self.cluster_stderr = io.read
       io.close
     end

     if scriptfile && File.exist?(scriptfile.to_s)
       self.script_text = File.read(scriptfile.to_s) rescue ""
     end

     if runtimefile && File.exist?(runtimefile.to_s)
       self.runtime_info = File.read(runtimefile.to_s) rescue ""
     end

     true
  end



  ##################################################################
  # Work Directory Archiving API
  ##################################################################

  def in_situ_workdir_archive_file #:nodoc:
    fn_id = self.fullname.gsub(/[^\w\-]+/,"_").sub(/\A_*/,"").sub(/_*$/,"")
    "CbrainTask_Workdir_#{fn_id}.tar.gz" # note: also check in the TaskWorkdirArchive model
  end

  # This method will create a .tar.gz file of the
  # content of the task's work directory. The tar
  # file will be left in the work directory itself,
  # and all other files will be removed. The
  # basename of the tar file can be obtained from
  # in_situ_workdir_archive_file(). Restoring the
  # state of the workdir can be performed with
  # unarchive_work_directory().
  def archive_work_directory

    # Keep updated_at value in order to reset it at the end of method
    updated_at_value = self.updated_at

    return false if self.share_wd_tid
    return true  if self.workdir_archived?

    cb_error "Tried to archive a task's work directory while in the wrong Rails app." unless
      self.bourreau_id == CBRAIN::SelfRemoteResourceId

    tar_file      = self.in_situ_workdir_archive_file
    temp_tar_file = "T_#{tar_file}"
    tar_capture   = "/tmp/tar.capture.#{Process.pid}.out"

    if self.status !~ /Completed|Failed|Terminated/
      self.addlog("Cannot archive: status is #{self.status}")
      return false
    end

    if self.cluster_workdir.blank?
      self.addlog("Cannot archive: no work directory configured.")
      return false
    end

    full=self.full_cluster_workdir
    if ! Dir.exists?(full)
      self.addlog("Cannot archive: work directory '#{full}' does not exist.")
      return false
    end

    # These two vars used only in rescue or ensure clauses
    full_tar_file      = (Pathname.new(full) + tar_file).to_s
    full_temp_tar_file = (Pathname.new(full) + temp_tar_file).to_s

    Dir.chdir(full) do

      if File.exists?(temp_tar_file)
        self.addlog("Cannot archive: it seems an archiving process is already in progress.")
        # TODO check date on temp_tar_file and proceed instead if it's really old?
        full_temp_tar_file = nil # so that nothing happens in ensure clause
        tar_capture        = nil # so that nothing happens in ensure clause
        return false
      end

      self.addlog("Attempting to archive work directory.")

      # Serialize a copy of the ActiveRecord for this task, for reference.
      File.open(".cbrain_task.json","w") do |fh|
        fh.write JSON.pretty_generate(JSON[self.to_json])
      end

      # Remove core files. Core file names can be customized by a sysadmin, so
      # we'll try with the two most common conventions: 'core' and 'core.PID'
      Dir.glob('core*').select { |f| f =~ /\Acore(\.\d+)?\z/ }.each do |corename|
         File.unlink(corename) if File.file?(corename)
      end

      system("chmod","-R","u+rwX",".") # uppercase X mode affects only directories
      status = with_stdout_stderr_capture(tar_capture) do
        system("tar","-czf", temp_tar_file, "--exclude", "*#{temp_tar_file}", ".")
        $? # a Process::Status object
      end

      # Note: we cannot rely on the return code of the tar command.
      if status.termsig
        self.addlog("Error creating TAR archive: got signal #{status.termsig}")
        return false
      end

      # Remove some common warnings
      # "tar: something.sock: socket ignored"
      # "tar: .: file changed as we read it"
      out = File.read(tar_capture) rescue ""
      out.gsub!(/tar.*ignored|tar.*changed as we read it/,"")

      if ! out.blank?
        outlines = out.split(/\n/)
        if outlines.size > 10
          outlines[10..99999] = [ "(#{outlines.size-10} more lines)" ]
        end
        self.addlog("Error creating TAR archive. Output of tar:\n#{outlines.join("\n")}")
        return false
      end

      if ! File.exists?(temp_tar_file)
        self.addlog("Error creating TAR archive: no file found after command, and no output?")
        return false
      end

      # Commented-out, as some tar implementations work fine and still return false
      # on warnings.
      #if ! ret
      #  self.addlog("Error creating TAR archive: the tar command returned false.")
      #  return false
      #end

      File.rename(temp_tar_file, tar_file)
      self.workdir_archived = true
      self.save!

      entries = Dir.entries(".").reject { |e| e == '.' || e == '..' || e == tar_file }
      entries.each { |e| FileUtils.remove_dir(e, true) rescue true }
    end

    self.update_size_of_cluster_workdir

    true

  # Error handling
  rescue => ex
    self.addlog_exception(ex, "Archiving process exception:")
    File.unlink(full_tar_file) rescue true
    return false

  # General cleanup
  ensure
    File.unlink(tar_capture)        rescue true
    File.unlink(full_temp_tar_file) rescue true
    # Reset update timestamp
    self.update_column(:updated_at, updated_at_value)
  end

  # This method performs the inverse of
  # archive_work_directory() : given a tar file
  # in the root of the work directory, it will
  # extract it then erase the tar file itself.
  def unarchive_work_directory
    return false if     self.share_wd_tid
    return true  unless self.workdir_archived?

    cb_error "Tried to unarchive a task's work directory while in the wrong Rails app." unless
      self.bourreau_id == CBRAIN::SelfRemoteResourceId

    tar_file      = self.in_situ_workdir_archive_file
    tar_capture   = "/tmp/tar.capture.#{Process.pid}.out"

    if self.cluster_workdir.blank?
      self.addlog("Cannot unarchive: no work directory configured.")
      return false
    end

    full=self.full_cluster_workdir
    if ! Dir.exists?(full)
      self.addlog("Cannot unarchive: work directory '#{full}' does not exist.")
      return false
    end

    Dir.chdir(full) do

      if ! File.exists?(tar_file)
        tar_file.sub!(/\.gz\z/,"") # try without the .gz
        if ! File.exists?(tar_file)
          self.addlog("Cannot unarchive: tar archive does not exist.")
          return false
        end
      end

      self.addlog("Attempting to unarchive work directory.")

      z_opt = (tar_file =~ /\.gz\z/i) ? "z" : ""
      status = with_stdout_stderr_capture(tar_capture) do
        system("tar", "-x#{z_opt}f", tar_file)
        $?
      end

      if status.termsig
        self.addlog("Error extracting TAR archive: got signal #{status.termsig}")
        return false
      end

      out = File.read(tar_capture) rescue ""
      if ! out.blank?
        outlines = out.split(/\n/)
        if outlines.size > 5
          outlines[5..99999] = [ "(#{outlines.size-5} more lines)" ]
        end
        self.addlog("Error extracting TAR archive. Output of tar:\n#{outlines.join("\n")}")
        return false
      end

      if ! status.success?
        self.addlog("Error extracting TAR archive: tar command returned false.")
        return false
      end

      File.unlink(tar_file) rescue true
    end

    # Mark task not archived; this also sets the updated_at timestamp
    # so that a task recently unarchived is considered 'updated'
    self.workdir_archived = false
    self.save!
    self.update_size_of_cluster_workdir

    true
  rescue => ex
    self.addlog_exception(ex, "Unarchiving process exception:")
    return false
  ensure
    File.unlink(tar_capture) rescue true
  end

  # This method performs the same steps as
  # archive_work_directory, with the added
  # steps that the tar file will be recorded
  # as a userfile belonging to the task's
  # owner and the work directory completely
  # erased. The data provider_for the file
  # is the task's results_data_provider_id.
  # Restoring the state of the workdir can be performed
  # with unarchive_work_directory_from_userfile().
  def archive_work_directory_to_userfile(dp_id = nil)
    return false unless self.archive_work_directory
    file_id  = self.workdir_archive_userfile_id
    return true if file_id

    full=self.full_cluster_workdir
    if ! Dir.exists?(full)
      self.addlog("Cannot archive: work directory '#{full}' does not exist.")
      return false
    end

    dp_dest = dp_id.presence || self.results_data_provider_id
    if dp_dest.blank?
      self.addlog("Cannot archive: no Data Provider specified.")
      return false
    end

    tar_file = self.in_situ_workdir_archive_file

    Dir.chdir(full) do
      if ! File.exists?(tar_file)
        self.addlog("Cannot archive: tar archive does not exist.")
        return false
      end
      self.addlog("Attempting to create TaskWorkdirArchive.")
      file     = safe_userfile_find_or_new(TaskWorkdirArchive,
                   :name             => tar_file,
                   :data_provider_id => dp_dest,
                   :user_id          => self.user_id,
                   :group_id         => self.group_id,
                   :hidden           => true
                 )
      file.save!
      file.cache_copy_from_local_file(tar_file)
      self.meta[:workdir_archive_hash] = file.cache_compute_md5sum.presence
      file.cache_erase
      file.save
      self.workdir_archive_userfile_id = file.id
      self.addlog_to_userfiles_created(file)
      self.addlog("Added archive file '#{file.name}' (ID #{file.id}).")
    end

    # Keep updated_at value in order to reset it at the end of method.
    updated_at_value = self.updated_at

    # Mark task as archived and remove the work directory.
    self.save
    self.remove_cluster_workdir

    # Reset update timestamp
    self.update_column(:updated_at, updated_at_value)

    true
  end

  # This method performs the inverse of
  # archive_work_directory_to_userfile() : using
  # the TaskWorkdirArchive file specified in
  # the workdir_archive_userfile_id attribute,
  # the method fetches it, and use its content
  # to recreate the task's work directory.
  def unarchive_work_directory_from_userfile
    tar_file = self.in_situ_workdir_archive_file

    return false unless self.workdir_archived? && self.workdir_archive_userfile_id

    cb_error "Tried to unarchive a TaskWorkdirArchive while in the wrong Rails app." unless
      self.bourreau_id == CBRAIN::SelfRemoteResourceId

    taskarch_userfile = TaskWorkdirArchive.find_by_id(self.workdir_archive_userfile_id)
    unless taskarch_userfile
      self.addlog("Cannot unarchive: TaskWorkdirArchive does not exist.")
      self.update_column(:workdir_archive_userfile_id,nil)
      return false
    end

    self.addlog("Attempting to restore TaskWorkdirArchive.")

    taskarch_userfile.sync_to_cache

    md5 = self.meta[:workdir_archive_hash]
    if md5.present? and md5 != taskarch_userfile.cache_compute_md5sum  #  presence check is compatibility layer for old tasks archives
      self.addlog("MD5 hash does not match stored record: task archive #{taskarch_userfile.name} is corrupted.")
      return false
    end

    self.make_cluster_workdir
    Dir.chdir(self.full_cluster_workdir) do
      safe_symlink(taskarch_userfile.cache_full_path, tar_file)
    end
    taskarch_userfile.addlog("Restored TaskWorkdirArchive as symlink in work directory.")

    return false unless self.unarchive_work_directory

    self.workdir_archive_userfile_id=nil
    self.save

    taskarch_userfile.destroy rescue true

  ensure
    File.unlink(tar_file) rescue true
  end


  ##################################################################
  # Cluster Task Status Update Methods
  ##################################################################

  protected

  # Returns the class name which implements this
  # Bourreau's cluster management system interface.
  # This is really a property of the whole Rails app,
  # but it's provided here in the model for convenience.
  def self.scir_class #:nodoc:
    @scir_class   ||= RemoteResource.current_resource.scir_class
  end

  # Returns the object which implements this
  # Bourreau's cluster management system's session.
  # This is really a property of the whole Rails app,
  # but it's provided here in the model for convenience.
  def self.scir_session #:nodoc:
    @scir_session ||= RemoteResource.current_resource.scir_session
  end

  # Returns the class name which implements this
  # Bourreau's cluster management system interface.
  # This is really a property of the whole Rails app,
  # but it's provided here in the model for convenience.
  def scir_class #:nodoc:
    self.class.scir_class
  end

  # Returns the object which implements this
  # Bourreau's cluster management system's session.
  # This is really a property of the whole Rails app,
  # but it's provided here in the model for convenience.
  def scir_session #:nodoc:
    self.class.scir_session
  end

  # The list of possible cluster states is different than
  # the ones we need for CBRAIN, so here is a mapping
  # to our shorter list. Note that when a job finishes
  # on the cluster, we cannot tell whether it was all
  # correctly done or not, so we only have "Does Not Exist"
  # as a state. It's up to the subclass' save_results()
  # to figure out if the processing was successful or
  # not.
  @@Cluster_States_To_Status ||= {
                               # The textual strings are important
                               # ---------------------------------
    Scir::STATE_UNDETERMINED          => "Does Not Exist",
    Scir::STATE_QUEUED_ACTIVE         => "Queued",
    Scir::STATE_SYSTEM_ON_HOLD        => "On Hold",
    Scir::STATE_USER_ON_HOLD          => "On Hold",
    Scir::STATE_USER_SYSTEM_ON_HOLD   => "On Hold",
    Scir::STATE_RUNNING               => "On CPU",
    Scir::STATE_SYSTEM_SUSPENDED      => "Suspended",
    Scir::STATE_USER_SUSPENDED        => "Suspended",
    Scir::STATE_USER_SYSTEM_SUSPENDED => "Suspended",
    Scir::STATE_DONE                  => "Does Not Exist",
    Scir::STATE_FAILED                => "Does Not Exist"
  }

  # Returns <b>On CPU</b>, <b>Queued</b>, <b>On Hold</b>, <b>Suspended</b> or
  # <b>Does Not Exist</b>.
  # This set of states is *NOT* exactly the same as for status()
  # as a non-existing cluster job might mean a job not started,
  # a killed job or a job that's exited properly, and we can't determine
  # which of the three from the job_ps()
  def cluster_status
    state = self.scir_session.job_ps(self.cluster_jobid, self.updated_at)
    status = @@Cluster_States_To_Status[state] || "Does Not Exist"
    return status
  rescue => ex
    logger.error("Cannot get cluster status for #{self.scir_session.class} ?!?") rescue nil
    logger.error("Exception was: #{ex.class} : #{ex.message}")                   rescue nil
    nil
  end



  ##################################################################
  # Cluster Task Creation Methods
  ##################################################################

  # Apply the environment variables configured in
  # the ToolConfig objects in effect for this job.
  def apply_tool_config_environment
    # Find the tool configuration in effect
    # We need three objects fetched through association;
    # each can be nil and in that case will be replaced by
    # a placeholder ToolConfig object which doesn't change
    # the environment.
    bourreau_glob_config = (self.bourreau && self.bourreau.global_tool_config) || ToolConfig.new(:description => 'Placeholder Global Bourreau')
    tool_glob_config     = (self.tool && self.tool.global_tool_config)         || ToolConfig.new(:description => 'Placeholder Global Tool')
    tool_config          = self.tool_config                                    || ToolConfig.new(:description => 'Placeholder TC')

    bourreau_glob_config.apply_environment(:extended) do
      tool_glob_config.apply_environment(:extended) do
        tool_config.apply_environment(:extended) do
          return yield
        end
      end
    end
  end


  # Submit the actual job request to the cluster management software.
  # Expects that the WD has already been changed.
  def submit_cluster_job
    self.addlog("Launching job on cluster.")

    commands = self.cluster_commands  # Supplied by subclass; can use self.params
    workdir  = self.full_cluster_workdir

    # Special case of RUBY-only jobs (jobs that have no cluster-side).
    # In this case, only the 'Setting Up' and 'Post Processing' states
    # are actually performed.
    if commands.blank? || commands.all? { |l| l.blank? }
      self.addlog("No BASH commands associated with this task. Jumping to state 'Data Ready'.")
      template = "CBRAIN Task Starting\n__CBRAIN_CAPTURE_PLACEHOLDER__\nCBRAIN Task Exiting\n"
      File.open(self.qsub_stdout_basename, "w") { |fh| fh.write template } # needed for checks
      File.open(self.qsub_stderr_basename, "w") { |fh| fh.write template } # needed for checks
      self.status_transition(self.status, "Data Ready")  # Will trigger Post Processing later on.
      self.save
      return true
    end

    # Find the tool configuration in effect
    # We need three objects, each can be nil.
    bourreau_glob_config = self.bourreau.global_tool_config
    tool_glob_config     = self.tool.global_tool_config
    tool_config          = self.tool_config
    bourreau_glob_config = nil if bourreau_glob_config && bourreau_glob_config.is_trivial?
    tool_glob_config     = nil if tool_glob_config     && tool_glob_config.is_trivial?
    tool_config          = nil if tool_config          && tool_config.is_trivial?
    self.addlog("Bourreau Global Config: ID=#{bourreau_glob_config.id}")           if bourreau_glob_config
    self.addlog("Tool Global Config: ID=#{tool_glob_config.id}")                   if tool_glob_config
    self.addlog("Tool Version: ID=#{tool_config.id}, #{tool_config.version_name}") if tool_config

    # Joined version of all the lines in the scientific script
    command_script = commands.join("\n")

    # In case of Docker or Singularity, we rewrite the scientific script inside
    # yet another wrapper script.
    if self.use_docker?
      command_script = wrap_new_HOME(command_script, self.full_cluster_workdir)
      command_script = self.docker_commands(command_script)
    elsif self.use_singularity?
      load_singularity_image
      command_script = self.singularity_commands(command_script) # note: invokes wrap_new_HOME itself
    else
      command_script = wrap_new_HOME(command_script, self.full_cluster_workdir)
    end

    # Create a bash science script out of the text
    # lines supplied by the subclass
    science_script = <<-SCIENCE_SCRIPT
#!/bin/bash

# Science script created automatically for #{self.class.to_s}
#   #{self.class.revision_info.to_s}
# by ClusterTask
#   #{ClusterTask.revision_info.to_s}

#{bourreau_glob_config ? bourreau_glob_config.to_bash_prologue(self.use_singularity?) : ""}
#{tool_glob_config     ? tool_glob_config.to_bash_prologue(self.use_singularity?)     : ""}
#{tool_config          ? tool_config.to_bash_prologue(self.use_singularity?)          : ""}
#{self.supplemental_cbrain_tool_config_init}

# CbrainTask '#{self.name}' commands section
#{command_script}

#{tool_config          ? tool_config.to_bash_epilogue          : ""}
#{tool_glob_config     ? tool_glob_config.to_bash_epilogue     : ""}
#{bourreau_glob_config ? bourreau_glob_config.to_bash_epilogue : ""}
    SCIENCE_SCRIPT
    sciencefile = self.science_script_basename.to_s
    File.open(sciencefile,"w") do |io|
      io.write( science_script )
    end

    # Create the QSUB wrapper script which is going to be submitted
    # to the cluster.
    qsub_script = <<-QSUB_SCRIPT
#!/bin/bash

# QSUB wrapper script created automatically by ClusterTask
#   #{ClusterTask.revision_info.to_s}

function got_sigterm {
  echo "CBRAIN Task Got TERM signal"
  exit 10
}
trap got_sigterm TERM

function got_sigxcpu {
  echo "CBRAIN Task Got XCPU signal"
  exit 10
}
trap got_sigxcpu XCPU

function got_sigxfsz {
  echo "CBRAIN Task Got XFSZ signal"
  exit 10
}
trap got_sigxfsz XFSZ

date '+CBRAIN Task Starting At %s : %F %T'
date '+CBRAIN Task Starting At %s : %F %T' 1>&2

# Record runtime environment
bash #{Rails.root.to_s.bash_escape}/vendor/cbrain/bin/runtime_info.sh > #{runtime_info_basename}

# With apptainer/singularity jobs, we sometimes get an error booting the container,
# so we try up to five times.
for singularity_attempts in 1 2 3 4 5 ; do  # note: the number 5 is used a bit below in an 'if'
  SECONDS=0 # this is a special bash variable, see the doc

  # stdout and stderr captured below will be re-substituted in
  # the output and error of this script here (this one!)
  bash '#{sciencefile}' >> #{science_stdout_basename} 2>> #{science_stderr_basename} </dev/null
  status="$?"

  test $status -eq 0 && break # all is good

  # Detect failed boot of singularity container
  if ! grep -i 'FATAL.*container.*creation.*failed' #{science_stderr_basename} >/dev/null ; then
    break # move on, for any other error or even non zero successes
  fi

  # Detect that final attempt to boot failed
  if test $singularity_attempts -eq 5 ; then
    echo "Apptainer container boot attempts all failed, giving up."
    status=99 # why not
    break
  fi

  # Cleanup and try again
  echo "Apptainer boot attempt number $singularity_attempts failed, trying again."
  grep -v -i 'FATAL.*container.*creation.*failed' < #{science_stderr_basename} > #{science_stderr_basename}.clean
  mv -f #{science_stderr_basename}.clean #{science_stderr_basename}
done

echo '__CBRAIN_CAPTURE_PLACEHOLDER__'      # where stdout captured above will be substituted
echo '__CBRAIN_CAPTURE_PLACEHOLDER__'      1>&2 # where stderr captured above will be substituted
date "+CBRAIN Task Ending With Status $status After $SECONDS seconds, at %s : %F %T"
date "+CBRAIN Task Ending With Status $status After $SECONDS seconds, at %s : %F %T" 1>&2

echo ''
echo 'CBRAIN Task CPU Times Start'
times # this is very important and the output is captured and parsed
echo 'CBRAIN Task CPU Times End'

echo "CBRAIN Task Exiting"       # checked by framework
echo "CBRAIN Task Exiting" 1>&2  # checked by framework
exit $status

    QSUB_SCRIPT
    qsubfile = self.qsub_script_basename.to_s
    File.open(qsubfile,"w") do |io|
      io.write( qsub_script )
    end

    # Create the cluster job object
    scir_class   = self.scir_class
    scir_session = self.scir_session
    job          = Scir.job_template_builder(scir_class)
    job.command  = "/bin/bash"
    job.arg      = [ qsubfile ]
    job.stdout   = ":" + self.full_cluster_workdir + "/" + qsub_stdout_basename # TODO remove ':' and let the Scir class add it if needed
    job.stderr   = ":" + self.full_cluster_workdir + "/" + qsub_stderr_basename
    job.join     = false
    job.wd       = workdir
    job.name     = self.tname_tid  # "#{self.name}-#{self.id}" # some clusters want all names to be different!
    job.walltime = self.job_walltime_estimate
    job.task_id  = self.id

    # Note: all extra_qsub_args defined in the tool_configs (bourreau, tool and bourreau/tool)
    # are appended by level of priority. 'less' specific first, 'more' specific later.
    # In this way if the same option is defined twice the more specific one will be the used.
    job.tc_extra_qsub_args  = ""
    job.tc_extra_qsub_args += "#{bourreau_glob_config.extra_qsub_args} " if bourreau_glob_config
    job.tc_extra_qsub_args += "#{tool_glob_config.extra_qsub_args} "     if tool_glob_config
    job.tc_extra_qsub_args += "#{tool_config.extra_qsub_args} "          if tool_config

    # Log version of Scir lib
    drm     = scir_class.drm_system
    version = scir_class.version
    impl    = scir_class.drmaa_implementation
    self.addlog("Using Scir for '#{drm}' version '#{version}' implementation '#{impl}'.")

    impl_revinfo = scir_session.revision_info
    impl_file    = impl_revinfo.basename
    impl_rev     = impl_revinfo.short_commit
    impl_author  = impl_revinfo.author
    impl_date    = impl_revinfo.date
    impl_time    = impl_revinfo.time
    self.addlog("Implementation in file '#{impl_file}' by '#{impl_author}' rev. '#{impl_rev}' from '#{impl_date + " " + impl_time}'.")

    # Erase leftover STDOUT and STDERR files; necessary
    # because some cluster management systems just append
    # to them, which can confuse CBRAIN tasks trying to parse
    # them at PostProcessing.
    File.unlink(qsub_stdout_basename)    rescue true
    File.unlink(qsub_stderr_basename)    rescue true
    File.unlink(stdout_cluster_filename) rescue true # note: this can be combined report and leave original science report in place
    File.unlink(stderr_cluster_filename) rescue true # same note

    # Some jobs are meant only to be fully configured by never actually submitted.
    if self.meta[:configure_only]
      self.addlog("This task is meant to be configured but not actually submitted.")
      self.status_transition(self.status, "Configured")
    else
      # Queue the job on the cluster and return true, at this point
      # it's not our 'job' to figure out if it worked or not.
      self.addlog("Cluster command: #{job.qsub_command}") if self.user.has_role? :admin_user
      begin
        jobid              = scir_session.run(job)
        self.cluster_jobid = jobid
        self.status_transition(self.status, "Queued")
        self.addlog("Queued as job ID '#{jobid}'" +
            " with walltime #{job.walltime}s and extra args are '#{job.tc_extra_qsub_args.presence || 'none provided'}'." )
      rescue NoVmAvailableError => ex
        # When the task is executed in a VM, it may not be submitted
        # right away when no VMs are available. In such a case, method
        # scir_cloud.run will raise an exception. We need to mask this
        # exception and put the task back to status "New" so that
        # submission will be attempted again by the Bourreau later
        # on. VMs may become available for the task when other tasks
        # complete or new VMs are started. Exceptions that are not of
        # class NoVMAvailableError will not be rescued.
        addlog(ex.message)
        addlog("Putting task back to status \"New\".")
        # This is unfortunate but we have to move back to status 'New'
        # to give a chance to the task to be submitted again when
        # there are VMs available. It shouldn't be too annoying
        # though, since caches will avoid useless file transfers. To
        # avoid this status transition, a new status could be
        # introduced between "Setting Up" and "Queued"
        # (e.g. "Scheduling"). That would require some more
        # modifications in the bourreau worker logic though, so that
        # tasks in status "Scheduling" are also picked up.
        self.status_transition(self.status,"New")
      end
    end
    self.save

    return true
  end



  ##################################################################
  # Cluster Job Work Directory Methods
  ##################################################################

  # Create the directory in which to run the job.
  # If the task contains the ID of another task in
  # the attribute :share_wd_tid, then that other
  # task's work directory will be used instead.
  def make_cluster_workdir

    # Test to see if it already exists; if so, use it.
    current = self.cluster_workdir
    if ! current.blank?
      full = self.full_cluster_workdir
      return true if File.directory?(full)
      self.cluster_workdir = nil # nihilate it
    end

    # Use the work directory of another task
    otask_id = self.share_wd_tid
    if ! otask_id.blank?
      otask = CbrainTask.find_by_id(otask_id)
      cb_error "Task '#{self.bname_tid}' is supposed to use the workdir of task '#{otask_id}' which doesn't exist." if ! otask
      cb_error "Cannot use the work directory of a task that belong to another Bourreau." if otask.bourreau_id != self.bourreau_id
      owd   = otask.full_cluster_workdir
      cb_error "Cannot find the work directory of other task '#{otask_id}'."      if owd.blank?
      cb_error "The work directory '#{owd} of task '#{otask_id}' does not exist." unless File.directory?(owd)
      #self.cluster_workdir = File.basename(owd) # no longer assigned
      self.addlog("Using workdir '#{owd}' of task '#{otask.bname_tid}'.")
      return
    end

    # Create our own work directory
    name        = self.name
    user        = self.user.login
    basedir     = "#{user}-#{name}-T#{self.id}"
    rel_path    = self.class.numerical_subdir_tree_components(self.id).join("/")
    self.cluster_workdir = "#{rel_path}/#{basedir}" # newest convention is "00/12/34/basedir".
    fulldir = self.full_cluster_workdir # builds using the cluster_workdir and the bourreau's cms_shared_dir
    self.addlog("Trying to create workdir '#{fulldir}'.")
    begin
      self.class.mkdir_numerical_subdir_tree_components(self.cluster_shared_dir, self.id) # mkdir "00/12/34"
      Dir.mkdir(fulldir,0700) unless File.directory?(fulldir)
      self.save
    rescue => ex
      self.cluster_workdir = nil
      self.save
      raise ex
    end
  end

  # Remove the directory created to run the job.
  def remove_cluster_workdir
    cb_error "Tried to remove a task's work directory while in the wrong Rails app." unless
      self.bourreau_id == CBRAIN::SelfRemoteResourceId
    return true if self.share_wd_tid.present?  # Do not erase if using some other task's workdir.
    full=self.full_cluster_workdir
    return if full.blank?
    self.addlog("Removing workdir '#{full}'.")
    FileUtils.remove_dir(full, true) rescue true
    self.class.rmdir_numerical_subdir_tree_components(self.cluster_shared_dir, self.id) rescue true
    self.cluster_workdir      = nil
    self.cluster_workdir_size = nil
    if self.workdir_archived? && self.workdir_archive_userfile_id.blank?
      self.workdir_archived = false # no longer archived on cluster!
    end
    self.save
    true
  end

  # Save the directory created to run the job.
  # The directory will be saved as a FileCollection
  # only if the task have a results Data Provider.
  def save_cluster_workdir(user_id)
    full_cluster_workdir = self.full_cluster_workdir
    user                 = User.find(user_id)

    # Some verification before saving the work directory
    cb_error "Tried to save a task's work directory while in the wrong Rails app." unless
      self.bourreau_id == CBRAIN::SelfRemoteResourceId

    if full_cluster_workdir.blank?
      self.addlog("Cannot save work directory: no task workdir was found")
      return
    end

    if self.workdir_archived
      self.addlog "Cannot save work directory: this task is archived"
      return
    end

    if self.share_wd_tid
      self.addlog "Cannot save work directory: this task doesn't have its own work directory"
      return
    end

    data_provider_id = self.results_data_provider_id || (user && user.meta[:pref_data_provider_id])
    if data_provider_id.blank?
      self.addlog("Cannot save work directory: the task should have a result Data Provider or user should have a default Data Provider")
      return
    end


    # Save under a new TaskRawWorkdir
    userfile_name   = "TaskRawWorkdir-#{self.tname_run_id}"
    file_collection = safe_userfile_find_or_new(TaskRawWorkdir,
        :name             => userfile_name,
        :data_provider_id => data_provider_id,
        :user_id          => user.id,
        :group_id         => user.own_group.id,
      )

    file_collection.cache_copy_from_local_file(full_cluster_workdir)

    if file_collection.save
      Message.send_message(user,
        :header        => "Saved task work directory",
        :description   => "Task work directory was saved as a TaskRawWorkdir",
        :variable_text => "For [[#{self.fullname}][/tasks/#{self.id}]] under [[#{userfile_name}][/userfiles/#{file_collection.id}]]",
        :type          => :notice,
      ) if user
      self.addlog("Saved work directory in TaskRawWorkdir #{userfile_name}.")
    else
      Message.send_message(user,
        :header        => "Could not save work directory",
        :description   => "Unable to save work directory for [[#{self.pretty_type}][/tasks/#{self.id}]]",
        :variable_text => "#{self.errors.full_messages.join("\n")}",
        :type          => :error,
      ) if user
      self.addlog("Could not save work directory.")
    end
  end



  # Compute size in bytes of the work directory; save it in the task's
  # attribute :cluster_workdir_size . Leaves nil if the directory doesn't
  # exist or any error occurred. Sets to '0' if the task uses another task's
  # work directory.
  def update_size_of_cluster_workdir
    if self.share_wd_tid
      self.update_attribute(:cluster_workdir_size,0)
      return 0
    end
    full=self.full_cluster_workdir
    self.cluster_workdir_size = nil
    if ( ! full.blank? ) && Dir.exists?(full)
      sizeline = IO.popen("du -s -k #{full.to_s.bash_escape}","r") { |fh| fh.readline rescue "" }
      if mat = sizeline.match(/^\s*(\d+)/) # in Ks
        bytes = mat[1].to_i.kilobytes
        return bytes if bytes == self.cluster_workdir_size # nothing has changed
        self.update_attribute(:cluster_workdir_size, bytes)
        self.addlog("Size of work directory: #{bytes} bytes.")
      end
    else
      self.update_attribute(:cluster_workdir_size,nil)
      self.update_attribute(:cluster_workdir,nil)
    end
    return self.cluster_workdir_size
  rescue
    return nil
  end

  # This will increase the "task_setup" counts of the
  # DataUsage records for any and all userfiles left in
  # the :interface_userfile_ids array of the task's params.
  def track_usage_of_input_files_after_setup #:nodoc:
    userfile_ids = self.params[:interface_userfile_ids] || []
    Userfile.joins(:group)
      .where('userfiles.id' => userfile_ids)
      .where('groups.track_usage' => true)
      .to_a
      .select { |userfile| userfile.is_locally_synced? }
      .each do |userfile|
        DataUsage.increase_task_setups(self.user, userfile)
      end
  end



  ##################################################################
  # Docker support methods
  ##################################################################

  # Returns true if the task's ToolConfig is configured to point to a docker image
  # for the task's processing.
  def use_docker?
    return self.tool_config.container_engine == "Docker" &&
         ( self.tool_config.containerhub_image_name.present? ||
           self.tool_config.container_image_userfile_id.present? )
  end

  # Return the 'docker' command to be used for the task; this is fetched
  # from the Bourreau's own attribute. Default: "docker".
  def docker_executable_name
    return self.bourreau.docker_executable_name.presence || "docker"
  end

  # Returns the command line(s) associated with the task, wrapped in
  # a Docker call if a Docker image has to be used. +command_script+
  # is the raw scientific bash script.
  def docker_commands(command_script)

    # Values we substitute in our script:

    # 1) The task class might specify an alternate work directory to use within the container
    container_work_dir = self.container_working_directory.to_s.presence if self.respond_to?(:container_working_directory)
    esc_cont_work_dir  = container_work_dir.try(:bash_escape) || '"${PWD}"' # must work with bash escaping

    # 2) The root of the DataProvider cache
    cache_dir          = self.bourreau.dp_cache_dir

    # 3) The root of the shared area for all CBRAIN tasks
    gridshare_dir      = self.bourreau.cms_shared_dir

    # 4) "docker load" commands for the images (local file or DockerHub)
    cmd_load_image     = load_docker_image_cmd

    # 5) Basename of the docker wrapper script
    docker_wrapper_basename = ".dockerjob.#{self.run_id}.sh"

    # 6) More -v (bind mounts) for all the local data providers.
    # This will be a string "-v path1:path1 -v path2:path2" etc.
    esc_local_dp_mountpoints = local_dp_storage_paths.inject("") do |dock_opts,path|
      "#{dock_opts} -v #{path.bash_escape}:#{path.bash_escape}"
    end

    # Here is the main script we return to CBRAIN
    docker_commands = <<-DOCKER_COMMANDS

# Build a local wrapper script to run in a docker container
cat << \"DOCKERJOB\" > #{docker_wrapper_basename.bash_escape}
#!/bin/bash -l

# Docker wrapper script created automatically for #{self.class.to_s}
#   #{self.class.revision_info.to_s}
# by ClusterTask
#   #{ClusterTask.revision_info.to_s}

# CBRAIN internal consistency test
if test -n "$UID" -a "X$UID" != "X#{Process.uid}" ; then
  echo "Docker internal script running with wrong UID (expected UID=#{Process.uid})"
  echo "Runtime IDs: `id`"
  exit 2
fi

# Scientific commands start here

#{command_script}
DOCKERJOB

# Make sure it is executable
chmod 755 #{docker_wrapper_basename.bash_escape}

#{cmd_load_image}

# Invoke docker with our wrapper script above
#{docker_executable_name}                        \\
    run                                          \\
    -u #{Process.uid}:#{Process.gid}             \\
    --rm                                         \\
    --entrypoint /bin/sh                         \\
    -v "${PWD}":#{esc_cont_work_dir}             \\
    -v #{cache_dir.bash_escape}:#{cache_dir.bash_escape}         \\
    -v #{gridshare_dir.bash_escape}:#{gridshare_dir.bash_escape} \\
    #{esc_local_dp_mountpoints}                  \\
    -w #{esc_cont_work_dir}                      \\
    "$docker_image_name"                         \\
    "${PWD}"/#{docker_wrapper_basename.bash_escape}

    DOCKER_COMMANDS

    return docker_commands
  end

  # Returns the bash statements necessary to pull a Docker image from
  # dockerhub, or load an image from a local file.
  # Then name of the image will be set in a bash variable 'docker_image_name'
  def load_docker_image_cmd #:nodoc:
    dockerhub_image_name = self.tool_config.containerhub_image_name
    docker_container_index = self.tool_config.container_index_location
    if docker_container_index.present?
      if !docker_container_index.end_with?('/')
        docker_container_index += '/'
      end
    else
      docker_container_index = ''
    end
    docker_container_index = docker_container_index + '/' if docker_container_index.present? && !docker_container_index.end_with?('/') # Add trailing / if not present and field not empty
    # Docker PULL
    if dockerhub_image_name.present?
      return <<-DOCKER_PULL
# Pull image from DockerHub
#{docker_executable_name} pull #{docker_container_index.bash_escape}#{dockerhub_image_name.bash_escape}
docker_image_name=#{dockerhub_image_name.bash_escape}
      DOCKER_PULL
    end

    # Docker LOAD (local image)
    if docker_image = self.tool_config.container_image # = not ==
      docker_image.sync_to_cache
      cachename     = docker_image.cache_full_path
      safe_symlink(cachename,docker_image.name)

      # We try to parse the content of the file 'repositories' in the TAR file
      repo_json    = `tar -xf #{docker_image.name.bash_escape} -O repositories 2>&1`
      repo_struct  = JSON.parse(repo_json)
      image_name   = repo_struct.keys.first
      image_ver    = repo_struct[image_name].keys.first
      full_image_name = "#{image_name}:#{image_ver}"

      return <<-DOCKER_LOAD
# Load docker image from tar file
#{docker_executable_name} load --input #{docker_image.name.bash_escape}
docker_image_name=#{full_image_name.bash_escape}
      DOCKER_LOAD
    end

    cb_error "Cannot generate docker load or pull commands..."
  end



  ##################################################################
  # Singularity support methods
  ##################################################################

  # Returns true if the task's ToolConfig is configured to point to a singularity image
  # for the task's processing.
  def use_singularity?
    return self.tool_config.use_singularity?
  end

  # Return the 'singularity' command to be used for the task; this is fetched
  # from the Bourreau's own attribute. Default: "singularity".
  def singularity_executable_name
    return self.bourreau.singularity_executable_name.presence || "singularity"
  end

  # Returns true if the admin has configured this option in the
  # task's ToolConfig attributes.
  def use_singularity_short_workdir?
    self.tool_config.singularity_use_short_workdir
  end

  # Returns the command line(s) associated with the task, wrapped in
  # a Singularity call if a Singularity image has to be used. +command_script+
  # is the raw scientific bash script.
  def singularity_commands(command_script)

    # Basename of the singularity wrapper script
    singularity_wrapper_basename = ".singularity.#{self.run_id}.sh"

    # Values we substitute in our script:
    # Numbers in (paren) correspond to the comment
    # block in the script, well below.

    # (7) The path to the task's work directory
    task_workdir   = self.full_cluster_workdir # a string
    short_workdir  = "/T#{self.id}" # only used in short workdir mode
    effect_workdir = use_singularity_short_workdir? ? short_workdir : task_workdir

    # (1) additional singularity execution command options defined in ToolConfig
    container_exec_args = self.tool_config.container_exec_args.presence

    # (2) The root of the DataProvider cache
    cache_dir      = self.bourreau.dp_cache_dir

    # (3) The root of the GridShare area (all tasks workdirs)
    gridshare_dir  = self.bourreau.cms_shared_dir # not mounted explicitely

    # (6) Ext3 capture mounts, if any.
    # These will look like "-B .capt_abcd.ext3:/path/workdir/abcd:image-src=/"
    # While we are building these options, we're also creating
    # the ext3 filesystems at the same time, if needed.
    esc_capture_mounts = ext3capture_basenames().inject("") do |sing_opts,(basename,size)|
      fs_name    = ".capt_#{basename}.ext3"      # e.g. .capt_work.ext3
      mountpoint = "#{effect_workdir}/#{basename}" # e.g. /path/to/workdir/work or /T123/work
      install_ext3fs_filesystem(fs_name,size)
      safe_mkdir(basename)
      "#{sing_opts} -B #{fs_name.bash_escape}:#{mountpoint.bash_escape}:image-src=/"
    end
    # This list will be used to make a device number check: all components
    # must be on a device different from the one for the work directory.
    capture_basenames = ext3capture_basenames.map { |basename,_| basename }

    # (4) More -B (bind mounts) for all the local data providers.
    # This will be a string "-B path1 -B path2 -B path3" etc.
    esc_local_dp_mountpoints = local_dp_storage_paths.inject("") do |sing_opts,path|
      "#{sing_opts} -B #{path.bash_escape}"
    end

    # (5) Overlays defined in the ToolConfig
    # Some of them might be patterns (e.g. /a/b/data*.squashfs) that need to
    # be resolved locally.
    # This will be a string "--overlay=path:ro --overlay=path:ro" etc.
    overlay_paths = self.tool_config.singularity_overlays_full_paths.map do |path|
      paths = Dir.glob(path) # checks on the local file system
      cb_error "Can't find any overlays matching '#{path}'" if paths.blank?
      paths
    end.flatten
    overlay_mounts = overlay_paths.inject("") do |sing_opts,path|
      "#{sing_opts} --overlay=#{path.bash_escape}:ro"
    end

    # Wrap new HOME environment
    command_script = wrap_new_HOME(command_script, effect_workdir)

    # Set singularity command
    singularity_commands = <<-SINGULARITY_COMMANDS

# Note to developers:
# During a standard CBRAIN task, this script is invoked with no arguments
# at all. For debugging situations, an admin can invoke it with the single
# argument "shell" to bypass the tool's execution and launch a convenient
# interactive shell inside the container.

# These two variables control the mode switching at the end of the script.
mode="exec"
sing_basename=./#{singularity_wrapper_basename.bash_escape} # note: the ./ is necessary

# In 'shell' mode we replace them with other things.
if test $# -eq 1 -a "X$1" = "Xshell" ; then
  mode="shell"
  sing_basename=""
fi

# Build a local wrapper script to run in a singularity container
cat << \"SINGULARITYJOB\" > #{singularity_wrapper_basename.bash_escape}
#!/bin/bash

# Singularity wrapper script created automatically for #{self.class.to_s}
#   #{self.class.revision_info.to_s}
# by ClusterTask
#   #{ClusterTask.revision_info.to_s}

# CBRAIN internal consistency test 1: must run under proper UID
if test "$UID" -ne "#{Process.uid}" ; then
  echo "Singularity internal script running with wrong UID (expected UID=#{Process.uid})"
  echo "Runtime IDs: `id`"
  exit 2
fi

# CBRAIN internal consistency test 2: must have the task workdir mounted inside the container
if test ! -d #{task_workdir.bash_escape} ; then
  echo "Container missing mount point for task work directory:" #{task_workdir.bash_escape}
  exit 2
fi

# CBRAIN internal consistency test 3: must have the cache_dir mounted inside the container
if test ! -d #{cache_dir.bash_escape} ; then
  echo "Container missing mount point for cache directory:" #{cache_dir.bash_escape}
  exit 2
fi

# CBRAIN internal consistency test 4: must have the gridshare_dir mounted inside the container
if test ! -d #{gridshare_dir.bash_escape} ; then
  echo "Container missing mount point for gridshare directory:" #{gridshare_dir.bash_escape}
  exit 2
fi

# CBRAIN internal consistency test 5: short task workdir (optional).
# It's possible the path below will be the same as the task workdir if no shortening
# is configured, so the test becomes trivially like test 2.
if test ! -d #{effect_workdir.bash_escape} ; then
  echo "Container missing shortened task work directory:" #{effect_workdir.bash_escape}
  exit 2
fi

# Make sure we are in the task's workdir now.
cd #{effect_workdir.bash_escape} || exit 2

# CBRAIN internal consistency test 6: all mounted ext3 filesystems should be
# on a device different from the task's workdir. Otherwise something went
# wrong with the mounts. Singularity or Apptainer can sometimes do that
# if the command is improperly built (order of mounts args etc).
workdir_devid=$(stat -c %d .)  # dev number of task workdir
for mount in #{capture_basenames.map(&:bash_escape).join(" ")} ; do
   mnt_devid=$(stat -c %d $mount 2>/dev/null)
   if test -z "$mnt_devid" ; then
     echo "Container missing mount point for '$mount'."
     exit 2
   fi
   if test "$workdir_devid" -eq "$mnt_devid" ; then
     echo "Container has mount point for '$mount' but it is not mounted to an external filesystem."
     exit 2
   fi
done

# Scientific commands start here

#{command_script}
SINGULARITYJOB

# Make sure it is executable
chmod 755 #{singularity_wrapper_basename.bash_escape}

# Invoke Singularity with our wrapper script above.
# Tricks used here:
# 1) we supply (if any) additional options for the exec command
# 2) we mount the local data provider cache root directory
#   a) at its original cluster full path
#   b) at /DP_Cache (used only when shortening workdir)
# 3) we mount the root of the gridshare area (for all tasks)
# 4) we mount each (if any) of the root directories for local data providers
# 5) we mount (if any) other fixed file system overlays
# 6) we mount (if any) capture ext3 filesystems
# 7) with -H we set the task's work directory as the singularity $HOME directory
#{singularity_executable_name}                  \\
    $mode                                       \\
    #{container_exec_args}                      \\
    -B #{cache_dir.bash_escape}                 \\
    -B #{cache_dir.bash_escape}:/DP_Cache       \\
    -B #{gridshare_dir.bash_escape}             \\
    #{esc_local_dp_mountpoints}                 \\
    #{overlay_mounts}                           \\
    -B #{task_workdir.bash_escape}:#{effect_workdir.bash_escape} \\
    #{esc_capture_mounts}                       \\
    -H #{effect_workdir.bash_escape}            \\
    #{container_image_name.bash_escape}         \\
    $sing_basename

    SINGULARITY_COMMANDS

    return singularity_commands
  end



  ##################################################################
  # Generic container support methods
  ##################################################################

  private

  # Add HOME switching back and forth to a bash script;
  # preserve the status returned by the script too.
  def wrap_new_HOME(script, new_home)
    new_home_script = <<-HOME_SWITCHING
# Preserve system HOME, then switch it
_cbrain_home_="$HOME"
export HOME=#{new_home.bash_escape}

#{script}

# Restore system HOME (while preserving the latest exit code)
_cbrain_status_="$?"
export HOME="$_cbrain_home_"
bash -c "exit $_cbrain_status_"
    HOME_SWITCHING
    new_home_script
  end

  # Returns an array of directory paths for all
  # online data providers that are local to the current
  # system (including smart ones). This is often needed
  # when setting up container environments so that these
  # DPs are mounted explicitly inside the containers.
  def local_dp_storage_paths #:nodoc:
    dirs = DataProvider
      .where(:online => true)
      .select { |dp| dp.is_fast_syncing? && dp.remote_dir.present? }
      .map(&:remote_dir)
      .select { |dir| File.directory?(dir) }
      .sort { |a,b| a <=> b } # ordered so deeper paths are last
    dirs
  end

  # Just invokes the same method on the task's ToolConfig.
  def ext3capture_basenames
    self.tool_config.ext3capture_basenames
  end

  # This method creates an empty +filename+ with +size+ bytes
  # (where size is specified like what the unix 'truncate' command accepts)
  # and then formats it with a ext3 filesystem. If the filename already exists,
  # nothing is done.
  def install_ext3fs_filesystem(filename,size) #:nodoc:
    if File.file?(filename) # already exists, all ok
      self.addlog("EXT3 filesystem file '#{filename}' already exists")
      return true
    end

    self.addlog("Creating EXT3 filesystem in '#{filename}' with size=#{size}")

    # Create an empty file of the proper size
    system("truncate -s #{size.bash_escape} #{filename.bash_escape}")
    status  = $? # A Process::Status object
    if ! status.success?
      cb_error "Cannot create EXT3 filesystem file '#{filename}': #{status.to_s}"
    end

    # Format it. Only works on linux obviously
    system("echo y | mkfs.ext3 -t ext3 -m 0 -q -E root_owner #{filename.bash_escape}")
    status  = $? # A Process::Status object
    if ! status.success?
      cb_error "Cannot format EXT3 filesystem file '#{filename}': #{status.to_s}"
    end

    true
  rescue => ex
    File.unlink(filename) rescue nil # keep directory clean of broken ext3 file
    raise ex
  end



  ##################################################################
  # Internal Subtask Submission Mechanism
  ##################################################################

  public

  # Handles +subtasks+ submitted while a task is running. To submit a subtask, a
  # task must create a ".new-task-*.json" JSON file at the root of its
  # work directory. Once a JSON file has been handled, it is deleted.
  def submit_subtasks_from_json
    workdir = self.full_cluster_workdir
    return nil if workdir.blank? || ! File.directory?(workdir) # in case workdir doesn't exist yet
    Dir.chdir(workdir) do
      taskfiles = Dir.glob(".new-task-*.json")
      return unless taskfiles.present?
      self.reload
      current_status = self.status
      return if     current_status == "Subtasking"
      return unless self.status_transition(current_status, "Subtasking") # ensures only one process can do the rest
      taskfiles.each do |taskfile|
        #self.addlog("Found new subtask file: #{taskfile}")
        begin
          file_content = File.read(taskfile)
          self.submit_task_from_string(taskfile,file_content)
        rescue => ex
          self.addlog_exception(ex,"Error submitting subtask")
        ensure
          File.unlink(taskfile) rescue nil # to make sure we won't retry forever
          #For debug
          #File.rename(taskfile,"#{taskfile}.processed")
        end
      end # each new json descriptor
      self.status_transition("Subtasking", current_status)
    end
  end

  protected

  # Creates and submits a subtask defined by a JSON object.
  # Parameters:
  # * json_string: A string containing a JSON object defining the task.
  #                Example:
  #                  {
  #                    "tool-class": "CbrainTask::TestTool",
  #                    "description": "A task running TestTool",
  #                    "parameters": {
  #                       "important_number": "123",
  #                       "dummy_parameter": "432"
  #                    }
  #                  }
  def submit_task_from_string(json_filename,json_string)

    # Parses JSON string and checks format
    validate_json_string(json_string) # Raises an exception if string is not valid
    new_task_hash = JSON.parse(json_string)

    # Extract the main info about this new task
    new_task_class_name  = new_task_hash["tool-class"].presence    || "ErrorNoSuchClassMyFriend"
    new_share_wd_tid     = new_task_hash["share-wd-tid"].presence     # optional
    new_tcid             = new_task_hash["tool-config-id"].presence   # optional
    new_params           = new_task_hash["parameters"].presence    || {}
    new_description      = new_task_hash["description"].presence   || "Task submitted by task #{self.id}"
    new_prereqs          = new_task_hash["prerequisites"].presence || ""

    # Prints log message in the task's logs
    self.addlog("Submitting new subtask #{new_task_class_name}")

    # Creates task
    new_task              = CbrainTask.const_get(new_task_class_name).new # Raises an exception if tool class is not found
    raise "Invalid tool class: #{new_task_class_name}" unless new_task.class < ClusterTask

    new_task.batch_id     = self.id
    self.level            = 0 if self.level.blank?
    new_task.level        = self.level + 1 # New task will be one level up its "parent" task in the task table.
    if new_share_wd_tid.present?
      new_share_wd_tid      = self.id if new_share_wd_tid == 0 # a value of 0 means current task
      new_task.share_workdir_with(new_share_wd_tid, "Queued")
    end

    # Sets tool config among tool configs accessible by user of current task
    new_tool                = new_task.tool
    accessible_tool_configs = ToolConfig.find_all_accessible_by_user(self.user).where(:tool_id => new_tool.id, :bourreau_id => self.bourreau_id)
    new_tcid                = accessible_tool_configs.limit(1).raw_first_column(:id)[0] if new_tcid.blank?
    if new_tcid.blank? || ! accessible_tool_configs.where(:id => new_tcid).exists?
      cb_error "Cannot find an acceptable tool config ID for this user, tool, and bourreau."
    end
    new_task.tool_config_id = new_tcid

    # Sets task parameters
    new_task.params = new_params.symbolize_keys

    # Sets task prerequisites
    new_prereqs.split(",").each do |dep_id|
      new_task.add_prerequisites_for_setup(dep_id,'Completed')
    end

    # Sets other task attributes
    # In the future, we could allow to register results to another data provider
    # or to submit the task to another bourreau. This would require to carefully
    # check permissions of the task's current user, though.
    new_task.description              = new_description
    new_task.user_id                  = self.user_id
    new_task.results_data_provider_id = self.results_data_provider_id
    new_task.bourreau_id              = self.bourreau_id
    new_task.group_id                 = self.group_id

    # Submits the task
    new_task.status = "New"
    new_task.save!

    # Returns subtask id to application as a tiny .cbid file
    taskid_filename = json_filename.sub(/\.json$/i,".cbid")
    File.write(taskid_filename, "#{new_task.id}\n" )

    # Add new task as a pre-requisite of the current task if requested
    if new_task_hash["required-to-post-process"]
      self.add_prerequisites_for_post_processing(new_task,'Completed')
      self.save!
    end

  end

  # Validates a JSON string against
  # the schema used to define new tasks.
  def validate_json_string json_string
    # The JSON schema could be extended with bourreau id and results
    # data provider id but that would require careful permission
    # checks. tool-config-id is not mandatory because it's specific
    # to a CBRAIN installation and cannot be easily obtained by an
    # external agent. In case no tool config id is provided, the first
    # accessible tool config id will be selected.
    schema = {
      "type"       => "object",
      "required"   => [ "tool-class", "parameters" ],
      "properties" => {
        "tool-class"     => { "type" => "string" },                                         # Class of the new task
        "tool-config-id" => { "type" => "number" },                                         # Tool config id of the new task
        "share-wd-tid"   => { "type" => "string" },                                         # ID of other task to share workdir
        "description"    => { "type" => "string" },                                         # Description of the new task
        "parameters"     => { "type" => "object", "properties" => {"type" => "string" } },  # Parameters of the new task
        "prerequisites"  => { "type" => "string" },                                         # List of task ids that are a prerequisite to setup the new task
        "required-to-post-process" => { "type" => "boolean" }  # If true, the current task will not post-process before the new task is completed
      }
    }
    JSON::Validator.validate!(schema,json_string) # raises an exception if json_string is not valid
  end

  ##################################################################
  # Singularity load
  ##################################################################

  private

  # Give a unique name for container image
  # This is used as an entry in the task's work directory, usually
  # as a symbolic link to the real content of the image.
  def container_image_name #:nodoc:
    ".container-#{self.id}.img"
  end

 # Load the singularity image either from a repository or from a CBRAIN file
  def load_singularity_image #:nodoc:
    if self.tool_config.container_image
      load_singularity_image_from_userfile
    elsif self.tool_config.containerhub_image_name
      load_singularity_image_from_repo
    else
      cb_error "Cannot find source for singularity image..."
    end
  end

  # Create a link to our image; the image is a registered CBRAIN file
  def load_singularity_image_from_userfile #:nodoc:
    singularity_image = self.tool_config.container_image
    self.addlog("Syncing the singularity image '#{singularity_image.name}'")

    # Sync the userfile content
    singularity_image.sync_to_cache

    # Create the symlink to the cached image.
    cachename = singularity_image.cache_full_path
    image_name = container_image_name
    safe_symlink(cachename,image_name)
  end

  # Perform the singularity build; the image will be cached
  # as a special, hidden userfile on the ScratchDataProvider.
  def load_singularity_image_from_repo #:nodoc:
    singularity_image_name     = self.tool_config.containerhub_image_name
    singularity_index_location = self.tool_config.container_index_location.presence || "shub://"

    self.addlog("Building singularity image '#{singularity_image_name}'")

    # Find or create the userfile holding the image content.
    scratch_name     = "Singularity-build-" + singularity_image_name.gsub(/[^a-z0-9_\.\-]+/i,"_") # must respect userfile convention.
    scratch_name.sub!(/(\.img)?$/i, ".img")
    scratch_userfile = SingularityImage.find_or_create_as_scratch(:name => scratch_name) do |cache_path|
      # Optimization: if another find_or_create_as_scratch has already beaten us to the punch
      # and dowloaded the file, just skip this block altogether. The way SyncStatus works, several
      # of these blocks can be scheduled to run, but only one will execute at at any given time.
      next if File.exists?(cache_path.to_s) && File.size(cache_path.to_s) > 0
      # Run singularity build command
      out, err = tool_config_system("umask 000; #{singularity_executable_name} build #{cache_path.to_s.bash_escape} #{singularity_index_location.bash_escape}#{singularity_image_name.bash_escape}")
      # Check that all is OK; if not we store the captured outputs for investigation
      if ! File.exists?(cache_path.to_s) || File.size(cache_path.to_s) < 500.kilobytes
        capfile = "singularity_build_traces-#{self.run_id}.txt"
        File.open(capfile,"w") do |fh|
          fh.write("=== Stdout ===\n#{out}\n=== Stderr ===\n#{err}\n=== ====== ===\n")
        end
        cb_error "Cannot build singularity image. Captured outputs are in #{capfile}"
      end
    end

    self.addlog("Image stored as scratch userfile '#{scratch_userfile.name}' (ID #{scratch_userfile.id})")

    # Create the symlink to the cached image.
    cachename  = scratch_userfile.cache_full_path
    image_name = container_image_name
    safe_symlink(cachename,image_name)
  end

  ##################################################################
  # Lifecycle hooks
  ##################################################################

  private

  # All object destruction also implies termination!
  def before_destroy_terminate_and_rm_workdir #:nodoc:
    self.terminate rescue true
    self.remove_cluster_workdir
    true
  end

  # Returns true only if
  def task_is_proper_subclass #:nodoc:
    return true if ClusterTask.descendants.include? self.class
    self.errors.add(:base, "is not a proper subclass of ClusterTask.")
    false
  end

  public # the callbacks below are handled by after_status_transtion()

  # Add up CPU usage when a task goes to "Data Ready" state
  def track_resource_usage_cpu(prevstate) #:nodoc:

    # We have to potential sources of information: the CBRAIN launch script and the scheduler
    cb_num_seconds_info    = nil
    sched_num_seconds_info = nil

    recorded_status        = self.status

    # Extract info from the captured qsub script output
    # The CBRAIN wrapper creates special tokens with the
    # outputs of the bash 'times' command.
    task_workdir = self.full_cluster_workdir
    if task_workdir.present?
      qsub_file = Pathname.new(task_workdir) + qsub_stdout_basename
      cb_num_seconds_info = extract_cpu_times_from_qsub_wrapper(qsub_file)
    end

    # If we can't read the CBRAIN info, it means the task was killed
    # outright before completing, so we should log that with a special token.
    # This happens usually when the scheduler killed the job,
    # so our wrapper script was not able to finish with its 'times' command.
    recorded_status = 'KilledByScheduler' if cb_num_seconds_info.blank? # not a real status

    # Extract info by querying the scheduler (not always implemented)
    sched_num_seconds_info = self.scir_session.job_cpu_info(self.cluster_jobid) rescue nil

    # Well, maybe we have nothing at all...
    return if cb_num_seconds_info.blank? && sched_num_seconds_info.blank?

    # Create a record with the max of each struct
    cb_num_seconds_info    ||= sched_num_seconds_info
    sched_num_seconds_info ||= cb_num_seconds_info
    max = ->(key) do
      cb_num_seconds_info[key] > sched_num_seconds_info[key] ?
      cb_num_seconds_info[key] : sched_num_seconds_info[key]
    end
    num_seconds_info = {
      :user_tot => max.(:user_tot),
      :syst_tot => max.(:syst_tot),
      :walltime => max.(:walltime),
    }

    # Create CPU time record
    cpu_time  = num_seconds_info[:user_tot] + num_seconds_info[:syst_tot]

    cpu_ru = CputimeResourceUsageForCbrainTask.create(
      :value              => cpu_time,
      :cbrain_task_status => recorded_status,
      :user_id            => self.user_id,
      :group_id           => self.group_id,
      :cbrain_task_id     => self.id,
      :remote_resource_id => self.bourreau_id,
      :tool_id            => self.tool.id,
      :tool_config_id     => self.tool_config_id,
    )

    # Create walltime record
    wall_time = num_seconds_info[:walltime]

    wt_ru = WalltimeResourceUsageForCbrainTask.create(
      :value              => wall_time,
      :cbrain_task_status => recorded_status,
      :user_id            => self.user_id,
      :group_id           => self.group_id,
      :cbrain_task_id     => self.id,
      :remote_resource_id => self.bourreau_id,
      :tool_id            => self.tool.id,
      :tool_config_id     => self.tool_config_id,
    )

    # Add CSV log entry; to enable configure a path in bourreau's meta data entry "user_logfile_path"
    user_logfile_path = self.bourreau.meta[:user_logfile_path].presence
    user_submit_log(user_logfile_path, cpu_ru, wt_ru) if user_logfile_path

  end

  # Add a task workdir size and the status of a task that reach
  # a final status.
  def track_resource_usage_final(prevstate) #:nodoc:
    SpaceResourceUsageForCbrainTask.create(
      :value              => self.cluster_workdir_size || 0, # just FYI
      :user_id            => self.user_id,
      :group_id           => self.group_id,
      :cbrain_task_id     => self.id,
      :remote_resource_id => self.bourreau_id,
      :tool_id            => self.tool.id,
      :tool_config_id     => self.tool_config_id,
    )
  end

  # This method does external logging to a file with a bunch of
  # attributes about a recently finished job (successful or not).
  def user_submit_log(user_logfile_path, cpu_ru, wt_ru) #:nodoc:
    user = self.user
    csv_values = [
      Time.now.iso8601,                      # DateTime
      user.login,                            # CBRAIN username
      user.meta[:globus_preferred_username], # User globus name
      user.meta[:globus_provider_name],      # User globus provider name
      self.cluster_jobid,                    # Cluster Job ID
      cpu_ru.tool_name,                      # Tool Name
      cpu_ru.tool_config_version_name,       # Tool version
      cpu_ru.value,                          # CPU time
      wt_ru.value                            # Wall time
    ]
    csv_row_txt = csv_values.map { |v| "\"#{v}\"" }.join(",") + "\n"
    File.open(user_logfile_path.to_s, "a") { |fh| fh.write csv_row_txt } # APPEND mode
  rescue => ex
    Rails.logger.error "Cannot append to user submit log file: #{ex.class}: #{ex.message}"
  end

  # Utility that should go in a separate framework.
  # This allows the caller to invoke system()
  # in a block with an argument list and not have to
  # go through an intermediate shell to capture
  # the output and error. This makes the $?
  # process status more reliably represent what
  # happened to the subprocess.
  #
  # This is unfortunately not thread-safe.
  def with_stdout_stderr_capture(outfilename, errfilename=nil)
    outfh = File.new(outfilename,"w")
    errfh = File.new(errfilename,"w") if errfilename
    prev_out = STDOUT.dup
    prev_err = STDERR.dup
    STDOUT.reopen(outfh)
    STDERR.reopen(errfh || outfh)
    yield
  rescue
    File.unlink(outfilename) rescue nil
    File.unlink(errfilename) rescue nil
  ensure
    STDOUT.reopen(prev_out) if prev_out
    STDERR.reopen(prev_err) if prev_err
  end

end

