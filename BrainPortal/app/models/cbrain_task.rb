
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

# Model representing a job request made to an remote execution server (Bourreau) on a cluster.
# Typically this class is not used directly, instead intermediate subclasses are
# used on the BrainPortal side and on the Bourreau side:
#
#   PortalTask  < CbrainTask # on portal side
#   ClusterTask < CbrainTask # on bourreau side
#
# Most of the methods here are useful both on the BrainPortal side and on
# the Bourreau side; for methods that should only be used on a particular
# side, see the classes PortalTask and ClusterTask respectively.
class CbrainTask < ApplicationRecord

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  include ResourceAccess

  before_validation     :set_group
  after_save            :after_save_set_batch_id
  after_destroy         :remove_workdir_archive

  validates_presence_of :user_id
  validates_presence_of :bourreau_id
  validates_presence_of :group_id
  validates_presence_of :status
  validates_presence_of :tool_config_id

  # Rails5 make belongs_to association required by default
  # Task presets have bourreau id set to 0,
  # that's why the :bourreau assocition should be optionnal
  belongs_to            :bourreau, optional: true
  belongs_to            :user
  belongs_to            :group
  belongs_to            :tool_config, :optional => true  # no TC means a task object containing 'presets'
  belongs_to            :results_data_provider, :class_name => 'DataProvider', :foreign_key => :results_data_provider_id, :optional => true
  belongs_to            :batch_master_task,     :class_name => 'CbrainTask',   :foreign_key => :batch_id, :optional => true

  belongs_to            :workdir_archive, :class_name => 'Userfile', :foreign_key => :workdir_archive_userfile_id, :optional => true

  # Resource usage is kept forever even if task is destroyed.
  has_many              :resource_usage

  # Returns the set of tasks in the same batch
  has_many :batch_tasks, :class_name => 'CbrainTask', :foreign_key => :batch_id, :primary_key => :batch_id

  # Pseudo Attributes (not saved in DB)
  # These are filled in by calling capture_job_out_err().
  attr_accessor  :cluster_stdout, :cluster_stderr, :script_text, :runtime_info

  # The attribute 'params' is a serialized hash table
  # containing job-specific parameters; it's up to each
  # subclass of CbrainTask to find/use/define its content
  # as necessary.
  serialize_as_indifferent_hash :params

  # What API users can see from a task
  api_attr_visible :type, :user_id, :group_id, :bourreau_id, :tool_config_id,
                   :batch_id, :params, :status, :created_at, :updated_at,
                   :run_number, :results_data_provider_id,
                   :cluster_workdir_size, :workdir_archived, :workdir_archive_userfile_id,
                   :description

  scope :status, lambda { |s|
                         case s.to_sym
                         when :completed
                           value = CbrainTask::COMPLETED_STATUS
                         when :running
                           value = CbrainTask::RUNNING_STATUS # standard path, including waiting states
                         when :active
                           value = CbrainTask::ACTIVE_STATUS # larger set than running
                         when :queued
                           value = CbrainTask::QUEUED_STATUS # wait states in standard path
                         when :processing
                           value = CbrainTask::PROCESSING_STATUS # code-running states in standard path
                         when :failed
                           value = CbrainTask::FAILED_STATUS
                         when :ruby
                           value = CbrainTask::RUBY_STATUS
                         else
                           value = s
                         end
                         where("cbrain_tasks.status" => value)
                       }

  scope :active,         -> { status( :active ) }
  scope :failed,         -> { status( :failed ) }
  scope :failed_setup,   -> { where( "cbrain_tasks.status" => 'Failed To Setup'       ) }
  scope :failed_cluster, -> { where( "cbrain_tasks.status" => 'Failed On Cluster'     ) }
  scope :failed_post,    -> { where( "cbrain_tasks.status" => 'Failed To PostProcess' ) }
  scope :setting_up,     -> { where( "cbrain_tasks.status" => 'Setting Up'            ) }
  scope :on_cpu,         -> { where( "cbrain_tasks.status" => 'On CPU'                ) }
  scope :post_proc,      -> { where( "cbrain_tasks.status" => 'Post Processing'       ) }
  scope :completed,      -> { where( "cbrain_tasks.status" => 'Completed'             ) }

  scope :real_tasks,
        -> { where( "cbrain_tasks.status <> 'Preset' AND cbrain_tasks.status <> 'SitePreset'" ) }

  scope :not_archived,
        -> { where( "cbrain_tasks.workdir_archived = 0 OR cbrain_tasks.workdir_archived IS NULL" ) }

  scope :archived_on_cluster,
        -> { where( "cbrain_tasks.workdir_archived" => true, "cbrain_tasks.workdir_archive_userfile_id" => nil ) }

  scope :archived_as_file,
        -> { where( "cbrain_tasks.workdir_archived" => true ).where( "cbrain_tasks.workdir_archive_userfile_id IS NOT NULL" ) }

  scope :shared_wd,
        -> { where( "cbrain_tasks.share_wd_tid IS NOT NULL" ) }

  scope :not_shared_wd,
        -> { where( "cbrain_tasks.share_wd_tid" => nil ) }

  scope :wd_present,
        -> { not_shared_wd.where( "cbrain_tasks.cluster_workdir IS NOT NULL" ) }

  scope :wd_not_present,
        -> { where( "cbrain_tasks.cluster_workdir" => nil ) }


  # The attribute 'prerequisites' is a serialized hash table
  # containing the information about whether the current
  # task depend on the states of other tasks. As an example,
  # if the hash is this:
  #
  #     {
  #        :for_setup           => { "T12" => "Queued", "T13" => "Completed" },
  #        :for_post_processing => { "T66" => "Failed" },
  #     }
  #
  # then the task will be setup by a Worker only when task #12 and #13 are
  # in the indicated states or further, and the task will enter post_process() only
  # when task #66 has failed. The only allowed keys right now are
  # :for_setup and :for_post_processing, as these are the only two
  # states triggered by Workers.
  #
  # The task's ID are serialized with strings with a prefix consisting
  # of the single character 'T'. This is needed so that the structure
  # is properly serialized in XML during ActiveResource transport.
  #
  # The only allowed state values for the conditions are:
  #
  #  - 'Queued' (which also covers ALL subsequent states up to 'Completed')
  #  - 'Data Ready' (which also covers 'Completed')
  #  - 'Completed'
  #  - 'Failed' (which covers all failures)
  #
  # As an aside, note that in a way, a task ID 'n' in the CbrainTask attribute
  # :share_wd_tid also implies this prerequisite:
  #
  #     :for_setup => { "T#{n}" => "Queued" }
  #
  # unless a more restrictive prerequisite is already supplied for task 'n'.
  serialize_as_indifferent_hash :prerequisites

  ##################################################################
  # Status Lists
  ##################################################################

  # List of status for tasks that have completed successfully.
  COMPLETED_STATUS  = [ "Completed" ]

  # List of status for tasks that are proceeding on the normal processing path.
  QUEUED_STATUS     = [ "New", "Standby", "Configured", "Queued", "On Hold", "Suspended", "Data Ready" ] # waiting for something

  # List of status for tasks that are actively processing (in Ruby stages or on CPU on the cluster)
  PROCESSING_STATUS = [ "Setting Up", "On CPU", "Post Processing" ] # actually running code

  # List of status for tasks that are considered active on the normal processing path.
  RUNNING_STATUS    = [ "New", "Setting Up", "Queued", "On CPU", "Data Ready", "Post Processing"] # main path

  # List of status for tasks that have failed.
  FAILED_STATUS     = [ "Failed To Setup", "Failed To PostProcess", "Failed On Cluster",
                        "Failed Setup Prerequisites", "Failed PostProcess Prerequisites",
                        "Terminated" ]

  # List of status for tasks that are on the 'recover' paths.
  RECOVER_STATUS    = [ "Recover Setup",    "Recover Cluster",    "Recover PostProcess",
                        "Recovering Setup", "Recovering Cluster", "Recovering PostProcess" ]

  # List of status for tasks that are on the 'restart' paths.
  RESTART_STATUS    = [ "Restart Setup",    "Restart Cluster",    "Restart PostProcess",
                        "Restarting Setup", "Restarting Cluster", "Restarting PostProcess" ]

  # List of other administrative status.
  OTHER_STATUS      = [ "Preset", "Duplicated" ]

  # List of status for tasks that are executing Ruby code.
  RUBY_STATUS       = [ "Setting Up", "Post Processing",
                        "Recovering Setup", "Recovering Cluster", "Recovering PostProcess",
                        "Restarting Setup", "Restarting Cluster", "Restarting PostProcess" ]

  # List of status for tasks that active in any way.
  ACTIVE_STATUS     = QUEUED_STATUS | PROCESSING_STATUS | RECOVER_STATUS | RESTART_STATUS

  # List of status for tasks that are in a final state.
  FINAL_STATUS      = COMPLETED_STATUS | FAILED_STATUS | [ "Terminated" ]

  # List of all status keywords.
  ALL_STATUS        = ACTIVE_STATUS | COMPLETED_STATUS | RUNNING_STATUS | FAILED_STATUS | OTHER_STATUS

  ##################################################################
  # Core Object Methods
  ##################################################################

  # Automatically register the task's version when new() is invoked.
  def initialize(arguments = {}) #:nodoc:
    super(arguments)
    baserev = Revision_info
    self.addlog("#{baserev.basename} rev. #{baserev.short_commit}", :caller_level => 3)
  end

  # Same as the standard ActiveRecord's to_xml, except that
  # the params hash is serialized as YAML
  def to_xml(options = {})
    yaml_params = (self.params || {}).to_yaml
    options[:methods] ||= []
    options[:methods] << :type
    options[:except]  ||= []
    options[:except]  << :params
    options[:procs]   ||= []
    options[:procs]   << Proc.new { |opts| opts[:builder].tag!('params', yaml_params) }
    super(options)
  end

  #######################################################
  # Task Launch API
  #######################################################

  # Special boolean properties of your task, returned as a
  # hash table. Used by CBRAIN rendering code to control
  # default elements. Advanced feature. The defaults
  # for all properties are 'false' so that subclass
  # only have to explicitly set the special properties
  # that they want 'true' (since nil is also false).
  def self.properties
    {
       :no_submit_button                   => false, # view will not automatically have a submit button
       :i_save_my_task_in_after_form       => false, # used by validation code for detected coding errors
       :i_save_my_tasks_in_final_task_list => false, # used by validation code for detected coding errors
       :no_presets                         => false, # view will not contain the preset load/save panel
       :use_parallelizer                   => false, # true or fixnum: turns on parallelization
       :readonly_input_files               => false, # doesn't require write access to input files
    }
  end


  ##################################################################
  # Utility Methods
  ##################################################################

  # Returns a simple name for the task (without the Cbrain prefix stuff).
  # Example: from 'CbrainTask::Civet' we get 'Civet'
  def name
    @name ||= self.class.to_s.demodulize
  end

  # Returns a longer name for the task (without the Cbrain prefix stuff)
  # that includes the task's Bourreau name. Example:
  #   'Civet@MyBourreau'
  def name_and_bourreau
    mybourreau = self.bourreau.name rescue "(Unknown)"
    "#{self.name}@#{mybourreau}"
  end

  # Returns a longer name for the task (without the Cbrain prefix stuff)
  # that includes the task's Bourreau name and ID. Example:
  #   'Civet@MyBourreau/23'
  def fullname
    myid = self.id || "(NoId)"
    "#{self.name_and_bourreau}/#{myid}"
  end

  # Use the associated tool name to define the pretty type
  def self.pretty_type
    self.tool.try(:name) || self.to_s.demodulize # if no tool is found, produces a default using the task's class
  end

  # This method can be used to return a 'pretty' version of
  # the name of this task, which can contain a bit of task-specific
  # information. e.g. "MyTask (2 files)". It's used in the task
  # index page. Don't make it too long, though, it's not a report.
  # The default is the same as the +name+ instance method.
  def pretty_name
    self.class.pretty_name
  end

  # For backward compatibility.
  # Invokes pretty_type().
  def self.pretty_name
    self.pretty_type
  end

  # Returns the Tool object associated with the task.
  # Unfortunately, there isn't a clear association between
  # a task and a tool; it's based on the class name stored
  # in one of the tool's attribute.
  def self.tool
    Tool.where( :cbrain_task_class_name => self.to_s ).first
  end

  # Same as the class method of the same name.
  def tool
    @tool_cache ||= self.class.tool
  end

  # Define sort orders that don't refer to actual columns in the table.
  def self.pseudo_sort_columns
    ["batch"]
  end

  # This method returns the full path of the task's work directory.
  # The old convention was to store the full path in the
  # :cluster_workdir.
  #
  #   CbrainTask#cluster_workdir => "/path/to/gridshare/taskdir" # not used anymore
  #
  # A newer convention was to store just the basename
  # and use the task's Bourreau's :cms_shared_dir attribute for the
  # prefix.
  #
  #   Bourreau#cms_share_dir     => "/path/to/gridshare"
  #   CbrainTask#cluster_workdir => "taskdir"
  #
  # The current convention is to store a prefix such
  # as "00/00/00/basename" in the task's attribute
  # and use the task's Bourreau's :cms_shared_dir attribute for the
  # prefix.
  #
  #   Bourreau#cms_share_dir     => "/path/to/gridshare"
  #   CbrainTask#cluster_workdir => "00/00/00/taskdir"
  #
  # This code handle all conventions, for historical tasks.
  def full_cluster_workdir(seen_tids = {}, options = {}) # seen_tids is an internal arg for breaking recursion
    shared_wd_tid = self.share_wd_tid

    # The most common situation: a task with its own work directory
    if share_wd_tid.blank?
      attval = self.cluster_workdir
      return attval if attval.blank? || attval =~ /\A\// # already full path?
      shared_dir = options[:cms_shared_dir] || self.cluster_shared_dir # from its bourreau's cms_shared_dir
      return nil if shared_dir.blank?
      return "#{shared_dir}/#{attval}"
    end

    # Prepare for recursion, we need to find the workdir of another task
    seen_tids[self.id] = true
    cb_error "Infinite loop in share_wd_tid sequence?!?" if seen_tids[shared_wd_tid]
    other_task = CbrainTask.find_by_id(shared_wd_tid)
    cb_error "Trying to find the shared workdir of task #{self.bname_tid}, got ID of missing task #{shared_wd_tid}" unless other_task
    cb_error "Trying to find the shared workdir of task #{self.bname_tid}, got sent to a task on a different Bourreau: #{other_task.bname_tid}" if other_task.bourreau_id != self.bourreau_id
    return other_task.full_cluster_workdir(seen_tids, options) # recurse
  end

  # Returns the task's bourreau's cms_shared_dir (which might not be
  # a valid path on the current host). Raises an exception if it's
  # not defined!
  def cluster_shared_dir
    mybourreau = self.bourreau
    cb_error "No Bourreau associated with this task." unless mybourreau
    shared_dir = mybourreau.cms_shared_dir
    cb_error "Cluster shared work directory not defined for Bourreau '#{self.bourreau.name}'." if shared_dir.blank?
    shared_dir
  end

  # Returns the first line of the description. This is usually
  # used to represent the 'name' for presets.
  def short_description
    description = self.description || ""
    raise "Internal error: can't parse description!?!" unless description =~ /\A(.+\n?)/ # the . doesn't match \n
    header = Regexp.last_match[1].strip
    header
  end



  ##################################################################
  # Useful ID Generators
  ##################################################################

  # Returns an ID string containing both the bourreau_id +bid+
  # and the task ID +tid+ in format "bid/tid". Example:
  #     "3/4"   # Bourreau ID 3, task ID 4
  def bid_tid
    @bid_tid ||= "#{self.bourreau_id || '?'}/#{self.id || '?'}"
  end

  # Returns an ID string containing both the bourreau_name +bname+
  # and the task ID +tid+ in format "bname/tid". Example:
  #     "Mammouth/4"   # Bourreau 'Mammouth', task ID 4
  def bname_tid
    @bname_tid ||= "#{self.bourreau.name || '?'}/#{self.id || '?'}"
  end

  # Returns an ID string containing both the bourreau_name +bname+
  # and the task ID +tid+ in format "bname-tid" ; this is suitable to
  # be used as part of a filename. Example:
  #     "Mammouth-4"   # Bourreau 'Mammouth', task ID 4
  def bname_tid_dashed
    @bname_tid_dashed ||= "#{self.bourreau.name || 'Unk'}-#{self.id || 'Unk'}"
  end

  # Returns an ID string containing both the task +tname+
  # and the task ID +tid+ in format "tname-tid". Example:
  #     "Civet-1234"   # Task 'Civet' with ID 1234
  def tname_tid
    @tname_tid ||= "#{self.name || '?'}-#{self.id || '?'}"
  end

  # Returns an ID string containing the task +tname+
  # and the run_id in format "tname-rid". Example:
  #     "Civet-1234-1"   # Task 'Civet' with ID 1234 and run number 1
  def tname_run_id
    @tname_run_id ||= "#{self.name || '?'}-#{self.run_id || '?'}"
  end

  ##################################################################
  # Run Number ID Methods
  ##################################################################

  # Returns the 'run_number' of a task; this allows running the same
  # task multiple times in the same work directory. The run number
  # is increased after each successful 'restart' operation, but it
  # stays the same in error recovery modes.
  def run_number
    super || 1
  end

  # A string, in format "#{task_id}-#{run_number}"
  def run_id(run_number=nil)
    "#{self.id}-#{run_number || self.run_number}"
  end



  ##################################################################
  # State Transition Support Methods
  ##################################################################

  def self.after_status_transition_callbacks #:nodoc:
    @_after_status_transition_callbacks ||= {}
  end

  def self.find_after_status_transition_callbacks(from_state, to_state) #:nodoc:
    if self.superclass.respond_to?(:find_after_status_transition_callbacks)
      merged = self.superclass.find_after_status_transition_callbacks(from_state, to_state)
    else
      merged = []
    end
    current = self.after_status_transition_callbacks
    [ '*', from_state ].each do |from|
      from_hash = current[from]
      next if from_hash.blank?
      [ '*', to_state ].each do |to|
        next if from == to
        cb_list = from_hash[to]
        next if cb_list.blank?
        cb_list.each do |toadd|
          merged.reject! { |x| x == toadd }
        end
        merged += cb_list
      end # TO state is '*' or some specific state
    end # FROM state is '*' or some specific state
    merged
  end

  # This method changes the status attribute
  # in the current task object to +to_state+ but
  # also makes sure the current value is +from_state+ .
  # The change is performed in a transaction where
  # the record is locked, to ensure the transition is
  # not trashed by another process. The method returns
  # true if the transition was successful, and false
  # if anything went wrong.
  def status_transition(from_state, to_state)
    self.save
    CbrainTask.transaction do
      self.lock!
      return false if self.status != from_state
      return true  if from_state == to_state # NOOP
      self.status = to_state
      self.save!
    end
    self.invoke_after_status_transition_callbacks(from_state, to_state)
    true
  end

  # This method acts like status_transition(),
  # but it raises a CbrainTransitionException
  # on failures.
  def status_transition!(from_state, to_state)
    unless status_transition(from_state,to_state)
      ohno = CbrainTransitionException.new(
        "Task status was changed before lock was acquired for task '#{self.id}'.\n" +
        "Expected: '#{from_state}' found: '#{self.status}'."
      )
      ohno.original_object  = self
      ohno.from_state       = from_state
      ohno.to_state         = to_state
      ohno.found_state      = self.status
      raise ohno
    end
    true
  end

  # This class method can be used to register methods that will
  # be invoked after certain transitions of the task's status.
  # For instance,
  #
  #   class CbrainTask::MyTask < ClusterTask
  #
  #     after_status_transition 'Setting Up', 'Queued',     :just_queued
  #     after_status_transition '*',          'Terminated', :when_terminated
  #     after_status_transition 'Completed',  '*',          :ok_restarting
  #     after_status_transition '*',          'On CPU',     Proc.new { |orig| puts "From #{orig} to On CPU" }
  #     after_status_transition '*',          /Failed/,     :something_failed
  #
  #   end
  #
  # The methods or Procs will be invoked with a single
  # argument, the state before the transition (useful when
  # the method is registered with a '*' in +from_state+, as
  # shown above, but not much use in other cases).
  def self.after_status_transition(from_state, to_state, method_or_proc)
    return true if from_state == to_state
    callbacks_hash = self.after_status_transition_callbacks
    from_states    = from_state == '*' ? [ '*' ] : ALL_STATUS.select { |s| from_state === s }
    to_states      = to_state   == '*' ? [ '*' ] : ALL_STATUS.select { |s| to_state   === s }
    from_states.each do |from|
      to_states.each do |to|
        callbacks_hash[from]     ||= {}
        callbacks_hash[from][to] ||= []
        callbacks_hash[from][to].reject! { |x| x == method_or_proc }
        callbacks_hash[from][to] << method_or_proc
      end
    end
    true
  end

  # Internal, used by status_transition() and status_transition!() after
  # a successful transition.
  def invoke_after_status_transition_callbacks(from_state, to_state) #:nodoc:
    return true if from_state == to_state
    callbacks_list = self.class.find_after_status_transition_callbacks(from_state, to_state)
    return true if callbacks_list.blank? || callbacks_list.empty?
    callbacks_list.all? do |method|
      method.to_proc.call(self,from_state)
    end # each method or proc
  rescue => ex
    self.addlog_exception(ex, "After status transition callback exception:")
    false
  end



  ##################################################################
  # Data Tracking Utility Methods
  ##################################################################

  # This method compares a params hash table +old_params+ with
  # a +new_params+ hash provided, and log all the
  # differences. The task object itself is not changed.
  # tool_params_only indicate to argument is technical
  #
  # +flatten_invoke+ is technical param, presently has no use, keep default value
  def log_params_changes(old_params = {}, new_params = {}, flatten_invoke=true)
    numchanges = 0
    if self.is_a?(BoutiquesPortalTask) && flatten_invoke
      # invoke is a hash with actual tool parameters
      numchanges = log_params_changes(old_params['invoke'], new_params['invoke'], false)  # a tool might have an invoke param itself
      old_params = old_params.except('invoke')
      new_params = new_params.except('invoke')
    end
    # presently most params seems to be either old/new_params hash keys or inside the invoke
    # but we can potentially get one day some mixed cases, e.g. when migrating tool from old
    # to new boutiques
    old_params.each do |ck,cv|
      if new_params.has_key?(ck)
        nv = new_params[ck]
        begin
          next if cv == nv
          next if cv.is_a?(String) && nv.is_a?(String) && cv.strip == nv.strip
          self.addlog("Changed key #{ck.inspect}, old=#{cv.inspect}, new=#{nv.inspect}")
        rescue
          self.addlog("Uncomparable key #{ck.inspect}, old=#{cv.inspect}, new=#{nv.inspect}")
        end
        numchanges += 1
        next
      end
      self.addlog("Deleted key #{ck.inspect} with value #{cv.inspect}")
      numchanges += 1
    end
    new_params.each do |nk,nv|
      next if old_params.has_key?(nk)
      self.addlog("Added key #{nk.inspect} with value #{nv.inspect}")
      numchanges += 1
    end

    return numchanges if ! flatten_invoke  # no count reporting until non-tool params compared

    if numchanges > 0
      self.addlog("Total of #{numchanges} changes observed.")
    else
      self.addlog("No changes to params observed.")
    end
  end



  ##################################################################
  # Prerequisites Methods And State Tables
  ##################################################################

  # List of prerequisites states and the set of states that
  # fulfill them.
  PREREQS_STATES_COVERED_BY = {

    'Queued' => { # Task must be AT LEAST 'Queued', but can be further along.
                  'Queued'                           => :go,
                  'On Hold'                          => :go,
                  'On CPU'                           => :go,
                  'Suspended'                        => :go,
                  'Data Ready'                       => :go,
                  'Post Processing'                  => :go,
                  'Completed'                        => :go,
                  'Terminated'                       => :fail,
                  'Failed To Setup'                  => :fail,
                  'Failed To PostProcess'            => :fail,
                  'Failed On Cluster'                => :fail,
                  'Failed Setup Prerequisites'       => :fail,
                  'Failed PostProcess Prerequisites' => :fail,
                },

    'Data Ready' => { # Task must be AT LEAST 'Data Ready', but can be further along.
                  'Data Ready'                       => :go,
                  'Post Processing'                  => :go,
                  'Completed'                        => :go,
                  'Terminated'                       => :fail,
                  'Failed To Setup'                  => :fail,
                  'Failed To PostProcess'            => :fail,
                  'Failed On Cluster'                => :fail,
                  'Failed Setup Prerequisites'       => :fail,
                  'Failed PostProcess Prerequisites' => :fail,
                },

    'Completed' => { # Task must be 'Completed'.
                  'Completed'                        => :go,
                  'Terminated'                       => :fail,
                  'Failed To Setup'                  => :fail,
                  'Failed To PostProcess'            => :fail,
                  'Failed On Cluster'                => :fail,
                  'Failed Setup Prerequisites'       => :fail,
                  'Failed PostProcess Prerequisites' => :fail,
                },

    'Failed' => { # Task must have failed.
                  'Completed'                        => :fail,
                  'Terminated'                       => :fail, # a terminated task is not 'failed'
                  'Failed To Setup'                  => :go,
                  'Failed To PostProcess'            => :go,
                  'Failed On Cluster'                => :go,
                  'Failed Setup Prerequisites'       => :go,
                  'Failed PostProcess Prerequisites' => :go,
                },

    'Standby' => { # Task must be in special 'Standby' mode (to be used by programmers for special stuff)
                  'Standby'                          => :go,
                  'Completed'                        => :fail,
                  'Terminated'                       => :fail,
                  'Failed To Setup'                  => :fail,
                  'Failed To PostProcess'            => :fail,
                  'Failed On Cluster'                => :fail,
                  'Failed Setup Prerequisites'       => :fail,
                  'Failed PostProcess Prerequisites' => :fail,
                },

    'Configured' => { # Task must be in 'Configured' mode (to be used by programmers for special stuff)
                  'Configured'                       => :go,
                  'Completed'                        => :fail,
                  'Terminated'                       => :fail,
                  'Failed To Setup'                  => :fail,
                  'Failed To PostProcess'            => :fail,
                  'Failed On Cluster'                => :fail,
                  'Failed Setup Prerequisites'       => :fail,
                  'Failed PostProcess Prerequisites' => :fail,
                },

    'AnyGo'     => ALL_STATUS.map { |s| [ s, :go   ] }.to_h,  # This can be used as a placeholder
    'AnyWait'   => ALL_STATUS.map { |s| [ s, :wait ] }.to_h,  # This can be used as a placeholder

  }

  # The previous table is missing lots of entries that are common
  # to all prereq states; we add them here. By default, any
  # current state other than those specified explicitly above
  # mean :wait .
  PREREQS_STATES_COVERED_BY.each_value do |states_go_wait_fail|
    states_go_wait_fail.reverse_merge!(
        { # ALL states should appear in this list.
          'Duplicated'                       => :wait,
          'Standby'                          => :wait,
          'Configured'                       => :wait,
          'New'                              => :wait,
          'Setting Up'                       => :wait,
          'Queued'                           => :wait,
          'On Hold'                          => :wait,
          'On CPU'                           => :wait,
          'Suspended'                        => :wait,
          'Data Ready'                       => :wait,
          'Post Processing'                  => :wait,
          'Completed'                        => :wait,
          'Terminated'                       => :wait,
          'Failed To Setup'                  => :wait,
          'Failed To PostProcess'            => :wait,
          'Failed On Cluster'                => :wait,
          'Failed Setup Prerequisites'       => :wait,
          'Failed PostProcess Prerequisites' => :wait,
          'Recover Setup'                    => :wait,
          'Recover Cluster'                  => :wait,
          'Recover PostProcess'              => :wait,
          'Recovering Setup'                 => :wait,
          'Recovering Cluster'               => :wait,
          'Recovering PostProcess'           => :wait,
          'Restart Setup'                    => :wait,
          'Restart Cluster'                  => :wait,
          'Restart PostProcess'              => :wait,
          'Restarting Setup'                 => :wait,
          'Restarting Cluster'               => :wait,
          'Restarting PostProcess'           => :wait,
          'Preset'                           => :wait,
          'SitePreset'                       => :wait,
        }
    )
  end


  # This method adds a prerequisite entry in the task's object;
  # the prerequisite will indicate that in order for the task to
  # be set up (when +for_what+ is :for_setup) or to enter post
  # processing (when +for_what+ is :for_post_processing), the
  # +othertask+ must be in +needed_state+ .
  #
  # If +needed_state+ is a single '-' (dash), whatever prerequisite
  # currently exists will be removed, instead.
  def add_prerequisites(for_what, othertask, needed_state = "Completed") #:nodoc:
    cb_error "Prerequisite argument 'for_what' must be :for_setup or :for_post_processing" unless
      for_what.is_a?(Symbol) && (for_what == :for_setup || for_what == :for_post_processing)
    cb_error "Prerequisite argument needed_state='#{needed_state}' is not allowed." unless
      needed_state == '-' || PREREQS_STATES_COVERED_BY[needed_state]
    otask_id = othertask.is_a?(CbrainTask) ? othertask.id : othertask.to_i
    cb_error "Cannot add a prerequisite based on a task that has no ID yet!" if otask_id.blank?
    cb_error "Cannot add a prerequisite for a task that depends on itself!"  if self.id == otask_id
    ttid = "T#{otask_id}"
    prereqs              = (self.prerequisites || {}).with_indifferent_access
    prereqs[for_what]  ||= {} # will be transformed into IndifferentAccess!!!
    task_list            = prereqs[for_what]
    if needed_state == '-'
      task_list.delete(ttid)
    else
      task_list[ttid] = needed_state
    end
    self.prerequisites = prereqs # in case it was blank originally
  end

  # This method removes a prerequisite entry in the task's object.
  # The prerequisite must have been added with add_prerequisites_* first.
  def remove_prerequisites(for_what, othertask) #:nodoc:
    add_prerequisites(for_what, othertask, '-')
  end

  # This method adds a prerequisite entry in the task's object;
  # the prerequisite will indicate that in order for the task to
  # be set up, the +othertask+ must be in +needed_state+ .
  # The argument +othertask+ can be a task object, or its ID.
  def add_prerequisites_for_setup(othertask, needed_state = "Completed")
    add_prerequisites(:for_setup, othertask, needed_state)
  end

  # This method adds a prerequisite entry in the task's object;
  # the prerequisite will indicate that in order for the task to
  # be enter post processing, the +othertask+ must be in +needed_state+ .
  # The argument +othertask+ can be a task object, or its ID.
  def add_prerequisites_for_post_processing(othertask, needed_state = "Completed")
    add_prerequisites(:for_post_processing, othertask, needed_state)
  end

  # This method removes a 'for_setup' prerequisite entry
  # from the task's object. See add_prerequisites_for_setup for
  # more info.
  def remove_prerequisites_for_setup(othertask)
    remove_prerequisites(:for_setup, othertask)
  end

  # This method removes a 'for_post_processing' prerequisite entry
  # from the task's object. See add_prerequisites_for_post_processing for
  # more info.
  def remove_prerequisites_for_post_processing(othertask)
    remove_prerequisites(:for_post_processing, othertask)
  end

  # This method sets the attribute :share_wd_tid to the
  # ID of the task +othertask+; it also sets up a prerequisite
  # rule such that the current task will not start (setup) until
  # +othertask+ is in state +needed_state+ (by default, "Completed",
  # but other legal values are "Data Ready" and "Queued").
  def share_workdir_with(othertask, needed_state = "Completed")
    otask_id = othertask.is_a?(CbrainTask) ? othertask.id : othertask.to_i
    cb_error "No task or task ID provided?" if otask_id.blank?
    self.share_wd_tid = otask_id
    add_prerequisites_for_setup(otask_id, needed_state)
  end



  ##################################################################
  # Internal Logging Methods
  ##################################################################

  # Overrides the default behavior of the ActRecLog addlog method
  # so that caller information is provided by default.
  def addlog(message,options={})
    caller_level = options[:caller_level] || 0
    caller_level += 1
    no_caller    = options.has_key?(:no_caller) ? options[:no_caller] : false
    super(message,options.dup.merge({ :no_caller => no_caller, :caller_level => caller_level }))
  end

  # Records in the task's log the info about an exception.
  # This happens frequently not only in this code here
  # but also in subclasses, in the Bourreau controller and in
  # the BourreauWorkers, so it's worth having this utility.
  # The method can also be called by CbrainTask programmers.
  #
  # If the exception is a CbrainException, no stack trace is logged,
  # only the message ends up in the log. It is assumed that the message
  # will be clear enough to identify what happened. A stack trace is logged
  # in other cases so a programmer can investigate the problem.
  def addlog_exception(exception,message="Exception raised:",backtrace_lines=15)
    message = "Exception raised:" if message.blank?
    message.sub!(/[\s:]*\z/,":")
    self.addlog("#{message} #{exception.class}: #{exception.message}", :caller_level => 1)
    if backtrace_lines > 0 && ! exception.is_a?(CbrainException)
      backtrace_lines = exception.backtrace.size if backtrace_lines >= exception.backtrace.size
      exception.cbrain_backtrace[0..backtrace_lines-1].each { |m| self.addlog(m, :no_caller => true) }
    end
    true
  end

  # Record the current RemoteResource's revision number.
  def addlog_current_resource_revision(message = "")
    rr     = RemoteResource.current_resource
    rrinfo = rr.info(:ping) # always local, will not trigger network query
    rr_rev = rrinfo.starttime_revision
    self.addlog("#{rr.class} rev. #{rr_rev} #{message}", :caller_level => 1 )
    true
  end



  ##################################################################
  # Archiving Support Methods
  ##################################################################

  # Returns nil if the task is not archived in any way;
  # returns :workdir if the task is archived in its own work directory,
  # returns :userfile if the task is archived as a userfile.
  def archived_status
    return nil       unless self.workdir_archived?
    return :userfile if     self.workdir_archive_userfile_id.present?
    return :workdir
  end



  ##################################################################
  # Duplication Support Methods
  ##################################################################

  def duplicate!(new_bourreau=self.bourreau, new_tool_config=nil)

    # If on the same Bourreau, we use the same TC
    new_tool_config ||= self.tool_config if new_bourreau.id == self.bourreau_id
    # Find a compatible TC on other bourreaux
    new_tool_config ||= self.tool_config
      .find_latest_compatible_for_user_on_bourreau!(
         self.user, new_bourreau,
      )

    # Create the new object
    task = self.class.new(self.attributes) # a kind of DUP!
    task.id                          = nil
    task.status                      = "Duplicated"
    task.tool_config_id              = new_tool_config.id
    task.bourreau_id                 = new_bourreau.id
    task.run_number                  = 0
    task.cluster_jobid               = nil
    task.cluster_workdir             = nil
    task.cluster_workdir_size        = nil
    task.workdir_archived            = false
    task.workdir_archive_userfile_id = nil
    task.zenodo_deposit_id           = nil
    task.zenodo_doi                  = nil
    task.addlog("Duplicated from task '#{self.bname_tid}'.")
    task.save!
  end



  ##################################################################
  # Output Renaming Helper Methods
  ##################################################################

  # Returns a hash table containing a basic list of substitution keywords
  # suitable to use with output_renaming_add_numbered_keywords() ; to this
  # hash you can add any number of other keywords. See the full example
  # in output_renaming_add_numbered_keywords().
  def output_renaming_standard_keywords
    now = Time.zone.now
    {
      "date"       => now.strftime("%Y-%m-%d"),
      "time"       => now.strftime("%H:%M:%S"),
      "task_id"    => self.id.to_s.presence || "UnknownTaskID",
      "run_number" => self.run_number.to_s  || "UnknownRunID",
      "cluster"    => self.bourreau.name,
    }
  end

  # Utility method to help create new numbered keywords for
  # the pattern renaming helpers. See the helper method
  # output_renaming_fieldset() in TaskFormHelper to create the
  # frontend. This method is normally used in save_results()
  # (in ClusterTask) to build a new filename for an output.
  # Here's an example. Let's say we have an input filename
  # and a output pattern:
  #
  #   infile   = params[:infilename]              # "patient-00123_45.txt.gz"
  #   pattern  = params[:output_renaming_pattern] # "out-{in-2}.{in-3}.{date}.gz"
  #
  # The user would like the output to be "out-00123.45.2013-03-18.gz".
  # So in save_results, you build a set of keywords:
  #
  #   keywords = output_renaming_standard_keywords # std keywords, like '{time}' and '{date}'
  #   output_renaming_add_numbered_keywords(keywords, infile, "in-") # add '{in-1}', '{in-2}' etc
  #
  # At this point, the hash table 'keywords' contains:
  #
  #   {
  #     'date' => '2013-03-18', 'time' => '11:56:09', 'run_number' => '1', 'cluster' => 'execname', 'task_id' => '12343',
  #     'in-1' => 'patient', 'in-2' => '00123', 'in-3' => '45', 'in-4' => 'txt', 'in-5' => 'gz'
  #   }
  #
  # Then you call the string method pattern_substitute() to build the
  # output filename:
  #
  #   outname = pattern.pattern_substitute(keywords)  # returns "out-00123.45.2013-03-18.gz"
  #
  def output_renaming_add_numbered_keywords(keywords, string_to_split, keyprefix)
    comps = string_to_split.split(/([a-z0-9]+)/i)
    1.step(comps.size-1,2) do |i|
      keyword           = "#{keyprefix}#{(i-1)/ 2+1}"
      keywords[keyword] = comps[i]
    end
    self
  end



  ##################################################################
  # Lifecycle hooks
  ##################################################################

  private

  def after_save_set_batch_id #:nodoc:
    return true if self.batch_id
    self.update_attribute(:batch_id, self.id) rescue true
    true
  end

  def set_group #:nodoc:
    unless self.group_id
      return true unless self.user_id
      owner = self.user
      unless owner
        errors.add(:base, "user_id does not point to an existing user.")
        return false
      end

      self.group_id = owner.own_group.id
    end
  end

  def remove_workdir_archive #:nodoc:
    archive = self.workdir_archive
    return true unless archive
    archive.destroy
    true
  rescue
    if archive
      archive.tag_ids |= [ self.class.destroyed_archived_tag.id ]
    end
    true
  end

  # This returns (and if necessary creates the first time)
  # a Tag object named 'TaskDestroyed', belonging to the main
  # admin, that is used to mark any TaskWorkdirArchive that
  # a user tried to delete but couldn't (e.g on unaccessible
  # or read-only DPs etc). The admin can later find and delete them
  # himself.
  def self.destroyed_archived_tag #:nodoc:
    @_destroyed_task_tag_ ||=
      Tag.find_or_create_by( :name     => 'TaskDestroyed',
                             :user_id  => User.admin.id,
                             :group_id => User.admin.own_group.id )
  end



  ##################################################################
  # Zenodo Publishing Support
  ##################################################################

  public

  def has_zenodo_capabilities? #:nodoc:
    return false if self.status != 'Completed'
    return false if ! self.respond_to?(:base_zenodo_deposit) || ! self.respond_to?(:zenodo_outputfile_ids)
    true
  end

  # Returns a structure with miscellaneous info about the task;
  # only really useful for a task that has completed.
  # Anything that can be captured that is not already in
  # the task's attributes, or its logs, is welcome here.
  # No specific schema is yet available for this.
  #
  # The +runtime_textfile+ is the content of the task's
  # .runtime_info.kv file, and if supplied the keys
  # and values will be added to the structure returned.
  def struct_runtime_info(runtime_textfile=self.runtime_info) #:nodoc:
    info = {
      :walltime_events => WalltimeResourceUsageForCbrainTask
                          .where(:cbrain_task_id => self.id)
                          .order(:created_at)
                          .map { |ru| [ ru.created_at, ru.value ] },
      :cputime_events  => CputimeResourceUsageForCbrainTask
                          .where(:cbrain_task_id => self.id)
                          .order(:created_at)
                          .map { |ru| [ ru.created_at, ru.value ] },
    }

    # Expects a textfile with plain "key=val" entries
    (runtime_textfile.presence || "").split("\n").each do |line|
      next unless line =~ /\A\s*(\w[\w\-]*)\s*=\s*(.*\S)\s*\z/
      key, val = Regexp.last_match[1,2]
      val.sub!(/\A["']/,"")
      val.sub!(/["']\z/,"")
      # Maybe do other substitutions on val here?
      info[key] = val
    end

    info
  end



  ##################################################################
  # CARMIN converters
  ##################################################################

  public

  # Carmin statuses:
  # [Initializing,Ready,Running,Finished,InitializationFailed,ExecutionFailed,Unknown,Killed]
  CARMIN_STATUS_MAP = {
    # CBRAIN Status              => CARMIN Status
    # -------------------------- => ---------------------
    "New"                        => "Initializing",
    "Setting Up"                 => "Initializing",
    "Standby"                    => "Initializing",
    "Configured"                 => "Initializing",
    "Queued"                     => "Ready", # not sure about that
    "On Hold"                    => "Ready", # not sure about that
    "On CPU"                     => "Running",
    "Suspended"                  => "Running",
    "Data Ready"                 => "Running",
    "Post Processing"            => "Running",
    "Completed"                  => "Finished",
    "Terminated"                 => "Killed",
    "Failed To Setup"            => "InitializationFailed",
    "Failed Setup Prerequisites" => "InitializationFailed",
    "Failed On Cluster"          => "ExecutionFailed",
  }
  ALL_STATUS.each do |status|
    CARMIN_STATUS_MAP[status] ||= "ExecutionFailed" if status =~ /Fail/
    CARMIN_STATUS_MAP[status] ||= "Initializing"    if status =~ /^(Recover|Restart)/
    CARMIN_STATUS_MAP[status] ||= "Unknown"
  end

  def to_carmin #:nodoc:
    {
      :identifier         => self.id.to_s,
      :name               => self.name,
      :pipelineIdentifier => self.tool_config.id,
      :status             => (CARMIN_STATUS_MAP[self.status] || "Unknown"),
      :inputValues        => self.params.dup,
      :returnedFiles      => [],
      :studyIdentifier    => self.group.name,
      :errorCode          => 0,
      :startDate          => self.created_at.to_i,
      :endDate            => self.updated_at.to_i,
    }
  end



  ##################################################################
  # BOOT-TIME Support
  ##################################################################

  # Patch: pre-load all model files for the subclasses
  def self.preload_subclasses
    [ CBRAIN::TasksPlugins_Dir, CBRAIN::TaskDescriptorsPlugins_Dir ].each do |dir|
      Dir.chdir(dir) do
        Dir.glob("*.rb").each do |rubyfile|
          next if rubyfile == 'cbrain_task_class_loader.rb'      # skip that
          next if rubyfile == 'cbrain_task_descriptor_loader.rb' # skip that

          model = rubyfile.sub(/.rb\z/, '')
          require_dependency "#{dir}/#{model}.rb" unless
            [ model.classify, model.camelize ].any? { |m| CbrainTask.const_defined?(m) rescue nil }
        end
      end
    end
  end

end

