
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
#   CbrainTask::PortalTask  < CbrainTask
#   CbrainTask::ClusterTask < CbrainTask
#
class CbrainTask < ActiveRecord::Base

  Revision_info="$Id$"

  include CbrainTaskLogging

  belongs_to            :bourreau
  belongs_to            :user

  validates_presence_of :user_id
  validates_presence_of :bourreau_id
  validates_presence_of :status

  # Pseudo Attributes (not saved in DB)
  attr_accessor :cluster_stdout, :cluster_stderr

  # The attribute 'params' is a serialized hash table
  # containing job-specific parameters; it's up to each
  # subclass of CbrainTask to find/use/define its content
  # as necessary.
  serialize :params

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
  RUNNING_STATUS   = [ "New", "Setting Up", "Queued", "On CPU", "Suspended", "On Hold", "Data Ready", "Post Processing"]
  FAILED_STATUS    = [ "Failed To Setup", "Failed To PostProcess", "Failed On Cluster",
                       "Failed Setup Prerequisites", "Failed PostProcess Prerequisites",
                       "Terminated" ]
  RECOVER_STATUS   = [ "Recover Setup",    "Recover Cluster",    "Recover PostProcess",
                       "Recovering Setup", "Recovering Cluster", "Recovering PostProcess" ]
  RESTART_STATUS   = [ "Restart Setup",    "Restart Cluster",    "Restart PostProcess",
                       "Restarting Setup", "Restarting Cluster", "Restarting PostProcess" ]
  OTHER_STATUS     = [ "Preset" ]


  ##################################################################
  # Utility Methods
  ##################################################################

  # Returns a simple name for the task (without the Cbrain prefix stuff).
  # Example: from 'CbrainTask::Civet' we get 'Civet'
  def name
    @name ||= self.class.to_s.sub(/^CbrainTask::/,"")
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
  def run_id
    "#{self.id}-#{self.run_number}"
  end



  ##################################################################
  # Data Tracking Utility Methods
  ##################################################################

  # This method compares a params hash table +old_params+ with
  # a +new_params+ hash provided, and log all the
  # differences. The task object itself is not changed.
  def log_params_changes(old_params = {}, new_params = {})
    old_params.each do |ck,cv|
      if new_params.has_key?(ck)
        nv = new_params[ck]
        begin
          next if cv == nv
          self.addlog("Changed key '#{ck.inspect}', old='#{cv.inspect}', new='#{nv.inspect}'")
        rescue
          self.addlog("Uncomparable key '#{ck.inspect}', old='#{cv.inspect}', new='#{nv.inspect}'")
        end
        next
      end
      self.addlog("Deleted key '#{ck.inspect}' with value '#{cv.inspect}'")
    end
    new_params.each do |nk,nv|
      next if old_params.has_key?(nk)
      self.addlog("Added key '#{nk.inspect}' with value '#{nv.inspect}'")
    end
  end



  ##################################################################
  # Prerequisites Methods And State Tables
  ##################################################################

  # List of prerequisites states and the set of states that
  # fulfill them.
  PREREQS_STATES_COVERED_BY = {
 
    'Queued' => {
                  'New'                              => :wait,
                  'Setting Up'                       => :wait,
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

    'Data Ready' => {
                  'New'                              => :wait,
                  'Setting Up'                       => :wait,
                  'Queued'                           => :wait,
                  'On Hold'                          => :wait,
                  'On CPU'                           => :wait,
                  'Suspended'                        => :wait,
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

    'Completed' => {
                  'New'                              => :wait,
                  'Setting Up'                       => :wait,
                  'Queued'                           => :wait,
                  'On Hold'                          => :wait,
                  'On CPU'                           => :wait,
                  'Suspended'                        => :wait,
                  'Data Ready'                       => :wait,
                  'Post Processing'                  => :wait,
                  'Completed'                        => :go,
                  'Terminated'                       => :fail,
                  'Failed To Setup'                  => :fail,
                  'Failed To PostProcess'            => :fail,
                  'Failed On Cluster'                => :fail,
                  'Failed Setup Prerequisites'       => :fail,
                  'Failed PostProcess Prerequisites' => :fail
                },

    'Failed' => {
                  'New'                              => :wait,
                  'Setting Up'                       => :wait,
                  'Queued'                           => :wait,
                  'On Hold'                          => :wait,
                  'On CPU'                           => :wait,
                  'Suspended'                        => :wait,
                  'Data Ready'                       => :wait,
                  'Post Processing'                  => :wait,
                  'Completed'                        => :fail,
                  'Terminated'                       => :fail, # a terminated task is not 'failed'
                  'Failed To Setup'                  => :go,
                  'Failed To PostProcess'            => :go,
                  'Failed On Cluster'                => :go,
                  'Failed Setup Prerequisites'       => :go,
                  'Failed PostProcess Prerequisites' => :go
                }

  }

  # The previous table is missing lots of entries that are common
  # to all prereq states; we add them here.
  PREREQS_STATES_COVERED_BY.each_value do |states_go_wait_fail|
    states_go_wait_fail.merge!(
        {
          'Recover Setup'          => :wait,
          'Recover Cluster'        => :wait,
          'Recover PostProcess'    => :wait,
          'Recovering Setup'       => :wait,
          'Recovering Cluster'     => :wait,
          'Recovering PostProcess' => :wait,
          'Restart Setup'          => :wait,
          'Restart Cluster'        => :wait,
          'Restart PostProcess'    => :wait,
          'Restarting Setup'       => :wait,
          'Restarting Cluster'     => :wait,
          'Restarting PostProcess' => :wait
        }
    )
  end
   

  # This method adds a prerequisite entry in the task's object;
  # the prerequisite will indicate that in order for the task to
  # be set up (when +for_what+ is :for_setup) or to enter post
  # processing (when +for_what+ is :for_post_processing), the
  # +othertask+ must be in +needed_state+ .
  def add_prerequisites(for_what, othertask, needed_state = "Completed") #:nodoc:
    cb_error "Prerequisite argument 'for_what' must be :for_setup or :for_post_processing" unless
      for_what.is_a?(Symbol) && (for_what == :for_setup || for_what == :for_post_processing)
    cb_error "Prerequisite argument needed_state='#{needed_state}' is not allowed." unless
      PREREQS_STATES_COVERED_BY[needed_state]
    otask_id = othertask.is_a?(CbrainTask) ? othertask.id : task.to_i
    cb_error "Cannot add a prerequisite based on a task that has no ID yet!" if otask_id.blank?
    cb_error "Cannot add a prerequisite for a task that depends on itself!"  if self.id == otask_id
    ttid = "T#{otask_id}"
    prereqs         = self.prerequisites || {}
    task_list       = prereqs[for_what]  ||= {}
    task_list[ttid] = needed_state
    self.prerequisites = prereqs # in case it was blank originally
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

end

