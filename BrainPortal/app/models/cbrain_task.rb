
#
# CBRAIN Project
#
# CbrainTask models
#
# Original author: Pierre Rioux
#
# $Id$
#

# Model representing a job request made to an remote execution server (Bourreau) on a cluster.
# Typically this class is not used directly, instead intermediate subclasses are
# used on the Portal side and on the Bourreau side:
#
#   PortalTask  < CbrainTask
#   ClusterTask < CbrainTask
#
class CbrainTask < ActiveRecord::Base

  Revision_info="$Id$"

  before_validation     :set_group
  before_create         :record_statistics

  validates_presence_of :user_id
  validates_presence_of :bourreau_id
  validates_presence_of :group_id
  validates_presence_of :status
  validates_presence_of :tool_config_id
  
  belongs_to            :bourreau
  belongs_to            :user
  belongs_to            :group
  belongs_to            :tool_config

  # Pseudo Attributes (not saved in DB)
  attr_accessor :cluster_stdout, :cluster_stderr, :script_text

  # The attribute 'params' is a serialized hash table
  # containing job-specific parameters; it's up to each
  # subclass of CbrainTask to find/use/define its content
  # as necessary.
  serialize :params
  
  named_scope :status, lambda { |s|  
                         case s.to_sym
                         when :completed
                           value = CbrainTask::COMPLETED_STATUS
                         when :running
                           value = CbrainTask::RUNNING_STATUS
                         when :active
                           value = CbrainTask::ACTIVE_STATUS # larger set than running
                         when :failed
                           value = CbrainTask::FAILED_STATUS
                         else
                           value = s
                         end
                         { :conditions => { :status => value } }    
                       }
  
  named_scope :custom_filter, lambda { |c| TaskCustomFilter.find(c).filter_scope(scoped({})).current_scoped_methods[:find] }

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
  # As an aide, note that in a way, a task ID 'n' in the CbrainTask attribute
  # :share_wd_tid also implies this prerequisite:
  #
  #     :for_setup => { "T#{n}" => "Queued" }
  #
  # unless a more restrictive prerequisite is already supplied for task 'n'.
  serialize :prerequisites

  ##################################################################
  # Status Lists
  ##################################################################

  COMPLETED_STATUS = [ "Completed" ]
  RUNNING_STATUS   = [ "Standby", "Configured", "New", "Setting Up", "Queued", "On CPU", "Suspended", "On Hold", "Data Ready", "Post Processing"]
  FAILED_STATUS    = [ "Failed To Setup", "Failed To PostProcess", "Failed On Cluster",
                       "Failed Setup Prerequisites", "Failed PostProcess Prerequisites",
                       "Terminated" ]
  RECOVER_STATUS   = [ "Recover Setup",    "Recover Cluster",    "Recover PostProcess",
                       "Recovering Setup", "Recovering Cluster", "Recovering PostProcess" ]
  RESTART_STATUS   = [ "Restart Setup",    "Restart Cluster",    "Restart PostProcess",
                       "Restarting Setup", "Restarting Cluster", "Restarting PostProcess" ]
  OTHER_STATUS     = [ "Preset", "Duplicated" ]

  ACTIVE_STATUS    = RUNNING_STATUS | RECOVER_STATUS | RESTART_STATUS

  ##################################################################
  # Core Object Methods
  ##################################################################

  # Automatically register the task's version when new() is invoked.
  def initialize(arguments = {}) #:nodoc:
    super(arguments)
    baserev = Revision_info
    self.addlog("#{baserev.svn_id_file} rev. #{baserev.svn_id_rev}")
  end

  ##################################################################
  # Utility Methods
  ##################################################################

  # Returns a simple name for the task (without the Cbrain prefix stuff).
  # Example: from 'CbrainTask::Civet' we get 'Civet'
  def name
    @name ||= self.class.to_s.sub(/^CbrainTask::/,"")
  end

  # Returns a longer name for the task (without the Cbrain prefix stuff)
  # that includes the task's Bourreau name.
  # Example: 'Civet@MyBourreau'
  def name_and_bourreau
    mybourreau = self.bourreau.name rescue "(Unknown)"
    "#{self.name}@#{mybourreau}"
  end

  # Returns a longer name for the task (without the Cbrain prefix stuff)
  # that includes the task's Bourreau name and ID.
  # Example: 'Civet@MyBourreau/23'
  def fullname
    myid = self.id || "(NoId)"
    "#{self.name_and_bourreau}/#{myid}"
  end

  # Returns the Tool object associated with the task.
  # Unfortunately, there isn't a clear association between
  # a task and a tool; it's based on the class name stored
  # in one of the tool's attribute.
  def self.tool
    @tool_cache ||= Tool.find(:first, :conditions => { :cbrain_task_class => self.to_s })
  end

  # Same as the class method of the same name.
  def tool
    self.class.tool
  end
  
  # Define sort orders that don't refer to actual columns in the table.
  def self.pseudo_sort_columns
    ["batch"]
  end
  
  #Adding defaults to standard ActiveRecord to_xml.
  def to_xml(options={})
       super(options.reverse_merge(:methods => :type ))
  end

  # This method returns the full path of the task's work directory;
  # the old convention was to store the full path in the
  # :cluster_workdir, while the new one is to store just the basename
  # and use the task's Bourreau's :cms_shared_dir attribute for the
  # rest.
  def full_cluster_workdir
    attval = self.cluster_workdir
    return attval if attval.blank? || attval =~ /^\// # already full path?
    shared_dir = self.cluster_shared_dir # from its bourreau's cms_shared_dir
    return shared_dir + "/" + attval
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
    


  ##################################################################
  # Useful ID Generators
  ##################################################################

  # Returns an ID string containing both the bourreau_id +bid+
  # and the task ID +tid+ in format "bid/tid". Example:
  #     "3/4"   # Bourreau #3, task #4
  def bid_tid
    @bid_tid ||= "#{self.bourreau_id || '?'}/#{self.id || '?'}"
  end

  # Returns an ID string containing both the bourreau_name +bname+
  # and the task ID +tid+ in format "bname/tid". Example:
  #     "Mammouth/4"   # Bourreau 'Mammouth', task #4
  def bname_tid
    @bname_tid ||= "#{self.bourreau.name || '?'}/#{self.id || '?'}"
  end

  # Returns an ID string containing both the bourreau_name +bname+
  # and the task ID +tid+ in format "bname-tid" ; this is suitable to
  # be used as part of a filename. Example:
  #     "Mammouth-4"   # Bourreau 'Mammouth', task #4
  def bname_tid_dashed
    @bname_tid_dashed ||= "#{self.bourreau.name || 'Unk'}-#{self.id || 'Unk'}"
  end



  ##################################################################
  # Run Number ID Methods
  ##################################################################

  # Returns the 'run_number' of a task; this allows running the same
  # task multiple times in the same work directory. The run number
  # is increased after each succesful 'restart' operation, but it
  # stays the same in error recovery modes.
  def run_number
    super || 1
  end

  # A string, in format "#{task_id}-#{run_number}"
  def run_id(run_number=nil)
    "#{self.id}-#{run_number || self.run_number}"
  end



  ##################################################################
  # Data Tracking Utility Methods
  ##################################################################

  # This method compares a params hash table +old_params+ with
  # a +new_params+ hash provided, and log all the
  # differences. The task object itself is not changed.
  def log_params_changes(old_params = {}, new_params = {})
    numchanges = 0
    old_params.each do |ck,cv|
      if new_params.has_key?(ck)
        nv = new_params[ck]
        begin
          next if cv == nv
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
                  'Failed PostProcess Prerequisites' => :fail
                },

    'Completed' => { # Task must be 'Completed'.
                  'Completed'                        => :go,
                  'Terminated'                       => :fail,
                  'Failed To Setup'                  => :fail,
                  'Failed To PostProcess'            => :fail,
                  'Failed On Cluster'                => :fail,
                  'Failed Setup Prerequisites'       => :fail,
                  'Failed PostProcess Prerequisites' => :fail
                },

    'Failed' => { # Task must have failed.
                  'Completed'                        => :fail,
                  'Terminated'                       => :fail, # a terminated task is not 'failed'
                  'Failed To Setup'                  => :go,
                  'Failed To PostProcess'            => :go,
                  'Failed On Cluster'                => :go,
                  'Failed Setup Prerequisites'       => :go,
                  'Failed PostProcess Prerequisites' => :go
                },

     'Standby' => { # Task must be in special 'Standby' mode (to be used by programmers for special stuff)
                  'Standby'                          => :go,
                  'Completed'                        => :fail,
                  'Terminated'                       => :fail,
                  'Failed To Setup'                  => :fail,
                  'Failed To PostProcess'            => :fail,
                  'Failed On Cluster'                => :fail,
                  'Failed Setup Prerequisites'       => :fail,
                  'Failed PostProcess Prerequisites' => :fail
                },

     'Configured' => { # Task must be in 'Configured' mode (to be used by programmers for special stuff)
                  'Configured'                       => :go,
                  'Completed'                        => :fail,
                  'Terminated'                       => :fail,
                  'Failed To Setup'                  => :fail,
                  'Failed To PostProcess'            => :fail,
                  'Failed On Cluster'                => :fail,
                  'Failed Setup Prerequisites'       => :fail,
                  'Failed PostProcess Prerequisites' => :fail
                }

  }

  # The previous table is missing lots of entries that are common
  # to all prereq states; we add them here. By default, any
  # current state other than those specified explicitely above
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
          'SitePreset'                       => :wait
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
    prereqs         = self.prerequisites || {}
    task_list       = prereqs[for_what]  ||= {}
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
  def addlog_exception(exception,message="Exception raised:",backtrace_lines=15)
    message = "Exception raised:" if message.blank?
    message.sub!(/[\s:]*$/,":")
    self.addlog("#{message} #{exception.class}: #{exception.message}", :caller_level => 1)
    if backtrace_lines > 0
      backtrace_lines = exception.backtrace.size if backtrace_lines >= exception.backtrace.size
      exception.backtrace[0..backtrace_lines-1].each { |m| self.addlog(m, :no_caller => true) }
    end
    true
  end

  # Record the current RemoteResource's revision number.
  def addlog_current_resource_revision(message = "")
    rr     = RemoteResource.current_resource
    rrinfo = rr.info # always local, will not trigger network query
    rr_rev = rrinfo.starttime_revision
    self.addlog("#{rr.class} rev. #{rr_rev} #{message}", :caller_level => 1 )
    true
  end
  
  
  ##################################################################
  # Lifecycle hooks
  ##################################################################

  private

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
   
  def record_statistics #:nodoc:
    @statistic = Statistic.new(:bourreau_id  => self.bourreau_id, :user_id => self.user_id, :task_name => self.class.name)
    @statistic.update_stats
  end

end

