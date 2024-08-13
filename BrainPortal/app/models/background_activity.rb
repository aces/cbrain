
#
# CBRAIN Project
#
# Copyright (C) 2008-2024
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

# Implements a mechanism to launch or schedule a processing
# 'activity' in background, tracked in the database. The
# activity is applied to a list of items (an arbitrary array
# of things), and the list is processed sequentially. As
# each item is processes, the status of the processing (successful
# or failed) is recorded.
#
# This class provides the abstract methods that are needed to be
# implemented in subclasses, alongside many utility methods for
# them. It also includes support methods for the Worker processes
# that are responsible for executing the activities. Worker processes are
# implemented elsewhere (e.g. in CBRAIN, in BackgroundActivityWorker).
#
# In the following documentation, a BackgroundActivity object is
# simply called a 'BAC'.
#
# The schema of the associated ActiveRecord object is described in
# schema.rb . It consists of these attributes:
#
#   id
#   type                # subclass name, e.g. BackgroundActivity::DoThingies
#   user_id             # user who owns this BAC
#   remote_resource_id  # which RAILS app within CBRAIN must run this
#   status              # state tracking
#   handler_lock        # when present, object is locked for processing
#   items               # array of items (serialized in DB)
#   current_item        # increasing counter within items, starts at 0
#   num_successes       # as processing goes on records successes
#   num_failures        # same for failures
#   messages            # array of string messages, aligned with items (serialized)
#   options             # hash of arbitrary options, specific to the BAC class
#   created_at
#   updated_at
#   start_at            # scheduled BAC; past dates always mean NOW
#   repeat              # controlled vocabulary of repeat keywords e.g. 'monday@10:00'
#
# Subclasses need to define these methods:
#
#   pretty_name                 # optional
#   pretty_description          # optional
#   process(item)               # mandatory
#   before_first_item           # optional
#   after_last_item             # optional
#   prepare_dynamic_items       # optional
#
# Subclasses can invoke these ApplicationRecord validators:
#
#   validates_bac_presence_of_option         :key1 [, key2 etc]
#   validates_dynamic_bac_presence_of_option :key1 [, key2 etc]
#
# Subclasses can invoke these ApplicationRecord before_save callbacks:
#
#   must_be_on_bourreau!
#   must_be_on_portal!
#
# Code that want to use the framework to create and schedule BACs
# can invoke these utility methods. These are mostly provided to
# help implement Worker or manager processes:
#
#   cancel!
#   suspend!
#   unsuspend!
#   get_lock
#   remote_lock
#   lock_yield_unlock
#   process_next_item_for_duration(time)
#   self.activate_scheduled(remote_resource_id)
#   schedule_dup
#   prepare_repeat!
#
class BackgroundActivity < ApplicationRecord

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  cbrain_abstract_model! # objects of this class are not to be instanciated

  serialize_as_indifferent_hash :items
  serialize                     :messages
  serialize_as_indifferent_hash :options

  validates_presence_of :status
  validate              :status_is_correct

  validates_presence_of :items
  validate              :items_is_array

  validate              :repeat_is_correct

  before_save           :add_empty_options
  after_destroy         :record_in_rails_log

  belongs_to :user
  belongs_to :remote_resource

  api_attr_visible :user_id, :remote_resource_id, :type,
                   :status, :items, :messages,
                   :current_item, :num_successes, :num_failures,
                   :handler_lock, :options, :updated_at

  ALL_STATUS = %w(
    InProgress Completed PartiallyCompleted Failed InternalError
              Cancelled          Suspended
    Scheduled CancelledScheduled SuspendedScheduled
  )

  # The different repeat patterns we support in the repeat attribute.
  # These are used in a validation method, repeat_is_correct()
  REPEAT_REGEXES = %w[
    one_shot (start)\+(\d+) (tomorrow)@(\d\d):(\d\d)
    (monday)@(\d\d):(\d\d) (tuesday)@(\d\d):(\d\d) (wednesday)@(\d\d):(\d\d)
    (thursday)@(\d\d):(\d\d) (friday)@(\d\d):(\d\d) (saturday)@(\d\d):(\d\d) (sunday)@(\d\d):(\d\d)
  ].map { |s| Regexp.new('\A'+s+'\z') }

  # This constant string is placed as the single element
  # in the items array when that array will be filled later on.
  # See also the methods configure_for_dynamic_items! and
  # is_configured_for_dymanic_items?
  DYNAMIC_TOKEN = '(DYNAMICALLY FETCHED)' #:nodoc:

  ###########################################
  # Utility scopes
  ###########################################

  scope :status,        ->(statuses) { where(:status => statuses) }
  scope :active,        -> { status %w( InProgress                              ) }
  scope :completed,     -> { status %w( Completed                               ) }
  scope :failed,        -> { status %w( PartiallyCompleted Failed InternalError ) }
  scope :suspended,     -> { status %w( Suspended SuspendedScheduled            ) }
  scope :scheduled,     -> { status %w( Scheduled SuspendedScheduled            ) }
  scope :cancelled,     -> { status %w( Cancelled CancelledScheduled            ) }
  scope :errored,       -> { status %w( InternalError                           ) }
  scope :finished,      -> { status %w( Completed PartiallyCompleted Failed InternalError Cancelled CancelledScheduled ) }
  scope :retryable,     -> { where     "retry_count   > 0"  }
  scope :unlocked,      -> { where     :handler_lock => nil }
  scope :locked,        -> { where.not :handler_lock => nil }
  scope :future,        -> { where     "start_at      > ?", DateTime.now }

  ###########################################
  # Main Implementable Methods For Subclasses
  ###########################################

  # Returns a pretty name; default is "Activity name" from the
  # class name BackgroundActivity::ActivityName, with
  # the name of the tasl of userfile custom filter found in
  # the options hash, if any, in parentheses at the end.
  def pretty_name
    base_pretty  = self.class.to_s.demodulize.underscore.humanize
    filter_name  = self.options_custom_filter_name
    base_pretty += " (#{filter_name})" if filter_name
    base_pretty
  end

  # Returns a longer description of the activity. Default is "".
  # In the interfaces, this shows up as an overlay.
  def pretty_description
    ""
  end

  protected

  # Abstract method that must be implemented in a subclass.
  # Must return two values: [ok, message] where ok is true or false
  # depending on whether or not the processing went OK, and a message
  # for the action (either OK message or error message)
  def process(item)
    [ false, "Not Yet Implemented" ]
  end

  # Abstract method. Invoked by the execution framework
  # just before processing the first item.
  def before_first_item
    true
  end

  # Abstract method. This method is invoked
  # automatically when a BackgroundActivity object
  # is created out of a 'Scheduled' object.
  # This is the place a subclass can prepare the
  # list of items when that list is dynamic.
  def prepare_dynamic_items
    true
  end

  # Abstract method. Invoked by the execution framework
  # just after processing the last item and having
  # changed the status.
  def after_last_item
    true
  end

  ###########################################
  # Worker-Level Framework Methods
  ###########################################

  public

  # Utility builder: returns an object with user_ids and items pre-filled,
  # status set to 'InProgress', and remote_resource set to current resource.
  def self.local_new(user_id, items, remote_resource_id=CBRAIN::SelfRemoteResourceId, options={})
    remote_resource_id ||= CBRAIN::SelfRemoteResourceId
    self.new(
      :status             => 'InProgress',
      :user_id            => user_id,
      :items              => Array(items),
      :remote_resource_id => remote_resource_id,
      :options            => options,
    )
  end

  # Process the next item in the list.
  # This method assumes we've acquired the lock on the record.
  def process_next_item

    return false if self.status != 'InProgress'
    self.start_at = nil

    # Find current index
    idx  = self.current_item

    # Callback where a subclass can do some special stuff
    # before the first item.
    begin
      self.prepare_dynamic_items if idx == 0 && self.is_configured_for_dynamic_items?
      self.before_first_item     if idx == 0
      self.save
    rescue => ex
      self.internal_error!("prepare_dynamic_items: #{ex.class} #{ex.message}")
      return false
    end

    # Find current item
    item = self.items[idx]
    return false if item.nil?

    # Main processing handler
    ok,message = nil,nil
    begin
      ok,message = self.process(item)
    rescue => ex
      ok      = false
      better_message = ex.message
      better_message.sub!(/\[WHERE.*/, "") if ex.is_a?(ActiveRecord::RecordNotFound)
      message = "#{ex.class}: #{better_message}"
    end

    # Record results of processing that item.
    self.messages      ||= []
    self.messages[idx]   = message
    self.num_successes  += 1 if   ok
    self.num_failures   += 1 if ! ok
    self.current_item    = idx+1

    # Check if we've reached the end; if so enter
    # a final state.
    if self.current_item >= items.size
      self.status = "Completed"          if self.num_successes  > 0 && self.num_failures == 0
      self.status = "Failed"             if self.num_successes == 0 && self.num_failures  > 0
      self.status = "PartiallyCompleted" if self.num_successes  > 0 && self.num_failures  > 0
    end

    self.save!

    # Initiate the retry mechanism if possible.
    retrying_bac = self.setup_retry! if self.status =~ /Failed|PartiallyCompleted/
    return false if retrying_bac

    # Callback where a subclass can do some special stuff
    # after the last item.
    begin
      self.after_last_item if self.current_item >= items.size
      self.save
    rescue => ex
      self.internal_error!("after_last_item: #{ex.class} #{ex.message}")
      return false
    end

    # Return true if there is more to do, potentially
    self.status == 'InProgress'
  end

  # Goes through the list of messages and
  # extract the 'significant' ones to show users.
  # Should return an array of strings.
  # This method should not produce too much text,
  # even when there are thousands of items in the
  # current object; the point is only to let the
  # user know what happened when error occured.
  #
  # The default behavior is to ignore all blank messages
  # or messages that are numbers (for background activities
  # that record IDs), and count the number of times
  # other messages repeat. Only the top 5 counts are shown.
  def uniq_counted_messages
    counts = (self.messages.presence || [])
      .reject     { |m| m.blank? || m.to_s =~ /^\d+$/ }
      .inject({}) { |c,m| c[m] ||= 0; c[m] += 1; c }
      .sort_by    { |_,c| c }
      .reverse
    counts[0..4].map { |m,c| "#{c}x #{m.strip}" }
  end

  ###########################################
  # Worker/Customer: State Transition Actions
  ###########################################

  def cancel!
    self.update_column(:status, 'Cancelled')          if self.status == 'InProgress' || self.status == 'Suspended'
    self.update_column(:status, 'CancelledScheduled') if self.status == 'Scheduled'  || self.status == 'SuspendedScheduled'
    self.status.starts_with? 'Cancelled'
  end

  def suspend!
    self.update_column(:status, 'Suspended')          if self.status == 'InProgress'
    self.update_column(:status, 'SuspendedScheduled') if self.status == 'Scheduled'
    self.status.starts_with? 'Suspended'
  end

  def unsuspend!
    self.update_column(:status, 'InProgress')         if self.status == 'Suspended'
    self.update_column(:status, 'Scheduled')          if self.status == 'SuspendedScheduled'
    self.status.match(/InProgress|Scheduled/)
  end

  def internal_error!(message=nil)
    self.update_column(:status, "InternalError")
    self.update_column(:handler_lock, nil)
    if message
      self.options ||= {}
      self.options[:internal_error_message] = message
    end
    self.save
  end

  ###########################################
  # Internal Locking System
  ###########################################

  def get_lock
    lock_key = self.uniq_thread_id
    return true if self.handler_lock == lock_key # I already locked this
    return nil  if self.handler_lock.present? # locked by another process
    self.class.transaction do
      self.lock!(true) # reloads the record
      return nil if self.handler_lock.present?
      self.update(:handler_lock => lock_key, :updated_at => Time.now)
    end
    return true
  rescue # couldn't obtain lock
    false
  end

  def remove_lock
    lock_key = self.uniq_thread_id
    return nil if self.handler_lock != lock_key
    self.update_column(:handler_lock, nil)
    true
  end

  def lock_yield_unlock
    return nil unless self.get_lock
    return yield self
  ensure
    self.remove_lock
  end

  def uniq_thread_id
    self.class.uniq_thread_id
  end

  def self.uniq_thread_id
    @shostname        ||= Socket.gethostname.to_s.sub(/\..*/,"") # short hostname
    #@unique_thread_id ||= "#{CBRAIN::CBRAIN_RAILS_APP_NAME}-#{Process.pid}-#{Thread.current.object_id}"
    @unique_thread_id ||= "#{@shostname}-PID#{Process.pid}-TH#{Thread.current.object_id}"
  end

  ############################################
  # Worker/Customer: main methods to run stuff
  ############################################

  # Note: does not lock first
  def process_next_items_for_duration(time)
    start = Time.now
    while (Time.now - start) < time
      break if ! self.process_next_item # returns nil if items all processed or status not InProgress
    end
  end

  # Scans the database, finds all BACs that are
  #
  # 1. on remote_resource_id
  # 2. with status 'Scheduled'
  # 3. currently unlocked
  # 4. with a start date before the current time
  #
  # and 'activate' them. A BAC that is found will then
  # be duplicated, the dup will run prepare_dynamic_items on it,
  # and saved it with status 'InProgress'. The original BAC
  # is then rescheduled for the next repeat time or destroyed
  # if this is not a repeatable BAC.
  def self.activate_scheduled(remote_resource_id)
    self.where(
      :remote_resource_id => remote_resource_id,
      :status             => 'Scheduled',
      :handler_lock       => nil,
    ).where(
      "start_at < ?",Time.now
    ).each do |bac|
      next unless bac.get_lock
      bac.schedule_dup # create a new BAC ready to run now
      bac.prepare_repeat!  # move start_at forward in time; can result in destroy() if it is a one-shot
      bac.remove_lock unless bac.destroyed?
    end
  end

  # Scans the database, finds all BACs that are
  #
  # 1. on +remote_resource_id+
  # 2. currently locked
  # 3. last updated at least +older_than+ ago (default: 12 hours)
  #
  # and mark them as 'InternalError'. The
  # BAC was being processed, but somehow
  # the processing client seems to have died.
  def self.cancel_crashed(remote_resource_id,older_than=12.hours)
    self.where(
      :remote_resource_id => remote_resource_id,
    ).where.not(
      :handler_lock       => nil,
    ).where(
      "updated_at < ?", older_than.ago
    ).each do |bac|
      bac.internal_error!('Cancelled crashed')
    end
  end

  # If the current object is a scheduled one,
  # will lock it and invoke schedule_dup().
  def activate!
    return nil unless self.status == 'Scheduled' || self.status == 'SuspendedScheduled'
    return nil unless self.get_lock
    newbac = self.schedule_dup
    self.remove_lock
    newbac
  end

  # Given an object in Scheduled state, will duplicate
  # it, and prepare the dup for immediate execution.
  # If the object is invalid (cannot be saved), then
  # it is discarded with no warnings.
  #
  # Returns the new object, or nil if no new object was created.
  def schedule_dup
    return nil unless self.status == 'Scheduled' || self.status == 'SuspendedScheduled'
    newbac              = self.dup
    newbac.status       = 'InProgress'
    newbac.handler_lock = nil
    newbac.start_at     = nil
    newbac.repeat       = nil
    newbac.prepare_dynamic_items
    newbac.save if ! newbac.is_configured_for_dynamic_items?
    newbac.id.present? ? newbac : nil
  end

  # Parses the string in the repeat attribute and reschedule
  # the start time to the next event time.
  def prepare_repeat!
    rep_code = self.repeat   # a string with an encoding of when to reschedule in the future

    # Simplest case
    if rep_code.blank? || rep_code == "one_shot"
      return self.destroy
    end

    # "start+NNN"
    if rep_code =~ /start\+(\d+)/i
      minutes = Regexp.last_match[1].to_i.minutes
      minutes = 10.minutes if minutes < 10.minutes # safety
      self.start_at = Time.now + minutes
      return self.save
    end

    # "tomorrow@HH:MM"
    # "monday@HH:MM" .. "sunday@HH:MM"
    if rep_code =~ /(tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday)@(\d\d):(\d\d)/i
      _,nextday,hour,minutes = Regexp.last_match.to_a

      if nextday == 'tomorrow'
        daystart = DateTime.now.tomorrow.at_beginning_of_day.getlocal
      else
        daystart = Date.parse(nextday) # this returns a day before or after today
        daystart = DateTime.parse(daystart.to_s + DateTime.now.zone)
      end

      self.start_at = daystart + hour.to_i.hours + minutes.to_i.minutes
      self.start_at = self.start_at + 7.days if self.start_at < DateTime.now
      return self.save
    end

    # The repeat attribute has a value we don't understand
    self.internal_error!('Bad repeat attribute')

  end

  # Resets a BAC to its initial state,
  # with all the counters set to 0 and all
  # messages zapped.
  def reset!(status = 'InProgress')
    self.status        = status
    self.current_item  = 0
    self.num_successes = 0
    self.num_failures  = 0
    self.messages      = []
  end

  #########################################################
  # Retry Mechanism Support Methods
  #########################################################

  # Sets to NIL the two attributes used for
  # tracking/triggering retries. This method is
  # used when cancelling the retry mechanism for any reason.
  def zap_retry_attributes
    self.retry_count = nil
    self.retry_delay = nil
  end

  # When invoked on an object that is in status Failed or PartiallyCompleted,
  # the method will implement a 'retry' step for the object. For this to
  # work, the attribute +retry_count+ must be greater than 0, and (optionally)
  # the attribute retry_delay need to be set to a number of seconds.
  #
  # A successful retry does all these things:
  #
  # 1- make a backup of the current object (with its own retry attributes zapped)
  # 2- reset all item counters to zero
  # 3- (in case of PartiallyCompleted) reset the item list to just
  # the list of items that failed
  # 4- reschedule the BAC to the current time + retry_delay
  # 5- internally double retry_delay (so that at the next retry, the
  # rescheduling happens even later)
  #
  # For step 3 to work, a BAC's class must implement the method indices_of_failures();
  # if this method doesn't exist, retrying will fail.
  #
  # If everything is ok, this method returns the backup object created
  # in step 1, otherwise it returns nil.
  def setup_retry!

    # First, a few consistency checks and cleanup at the same time.
    if (self.status !~ /Failed|PartiallyCompleted/) ||
       (self.retry_count.blank?)                    ||
       (self.retry_count < 1)                       ||
       (self.status == "PartiallyCompleted" && ! self.respond_to?(:indices_of_failures))
      self.zap_retry_attributes
      self.save
      return nil
    end

    # Create the backup BAC, just for tracking the history of the failure.
    # That BAC cannot do anything but stay in the DB. It cannot be retried.
    # (Note: We will save this at the end, when everything's found to be ready)
    backup_bac = self.dup
    backup_bac.zap_retry_attributes
    backup_bac.handler_lock = nil

    # Prepare the new list of items. If the
    # bac is in Failed state, we just reprocess
    # everything so we don't need to adjust the list.
    # If the bac is in PartiallyCompleted state,
    # we extract just the elements to try again.
    if self.status = "PartiallyCompleted"
      fail_idx = self.indices_of_failures rescue nil
      if fail_idx.blank? || (!fail_idx.is_a?(Array)) # that's an error
        self.internal_error!('Bad value for indices_of_failures()')
        return nil
      end
      orig_items = self.items
      new_items  = fail_idx.sort.map { |i| orig_items[i] }.compact
      if new_items.blank?
        self.internal_error!('No items list after retry')
        return nil
      end
      self.items = new_items
    end

    # Adjust the retry count and retry delay
    self.retry_count = self.retry_count - 1
    delay = self.retry_delay || 60 # seconds
    delay = 60 if delay < 60 # just to be safe
    self.retry_delay = delay * 2
    self.zap_retry_attributes if self.retry_count < 1 # we are doing the final retry

    # Configure the delay
    self.start_at = Time.now + delay.seconds

    # Reset the counters, ready to retry!
    self.reset!('InProgress')

    # Save the two objects:
    # (1) The backup object
    backup_bac.retry_main_bac_id = self.id
    backup_bac.save
    # (2) Ourselves, with the ID of the backup
    self.retry_backup_bac_ids << backup_bac.id # push on a list
    self.save!

    return backup_bac
  rescue => ex
    self.internal_error!("setup_retry: #{ex.class} #{ex.message} #{ex.backtrace.first}")
    return nil
  end

  # On a retry backup object, returns the ID of the main target
  # of the retry mechanism.
  def retry_main_bac_id
    self.options[:_retry_main_bac_id]
  end

  # On a retry backup object, sets the ID of the main target
  # of the retry mechanism.
  def retry_main_bac_id=(bac_id)
    self.options ||= {}
    self.options[:_retry_main_bac_id] = bac_id
  end

  # On the main target of a retry, returns the array
  # of the backup objects.
  def retry_backup_bac_ids
    self.options ||= {}
    self.options[:_retry_backup_bac_ids] ||= []
  end

  ###########################################
  # Dynamic Items Support Methods
  ###########################################

  # Crushes the items attribute and replaces it
  # with a special unique value to represent that
  # the items list will be filled later, dynamically
  def configure_for_dynamic_items!
    self.items = [ DYNAMIC_TOKEN ]
    self
  end

  def is_configured_for_dynamic_items?
    self.items.present? && self.items.size == 1 && self.items.first == DYNAMIC_TOKEN
  end

  # Fetches the ID of a UserfileCustomFilter from
  #   options[:userfile_custom_filter_id]
  # and applies to the given scope; the list of Userfile IDs is then
  # saved in the items list.
  def populate_items_from_userfile_custom_filter(scope = Userfile.all)
    return unless self.is_configured_for_dynamic_items?
    userfile_custom_filter = UserfileCustomFilter.find(self.options[:userfile_custom_filter_id])
    self.items = userfile_custom_filter.filter_scope(scope).pluck(:id)
  end

  # Fetches the ID of a TaskCustomFilter from
  #   options[:task_custom_filter_id]
  # and applies to the given scope; the list of CbrainTask IDs is then
  # saved in the items list.
  def populate_items_from_task_custom_filter(scope = CbrainTask.all)
    return unless self.is_configured_for_dynamic_items?
    task_custom_filter = TaskCustomFilter.find(self.options[:task_custom_filter_id])
    self.items = task_custom_filter.filter_scope(scope).pluck(:id)
  end

  # Returns the name of the Userfile or Task custom filter
  # configured in the options hash, if any. Can be used by pretty_name()
  def options_custom_filter_name
    myoptions = self.options || {}
    ucf_id = myoptions[:userfile_custom_filter_id].presence
    if ucf_id
      return UserfileCustomFilter.where(:id => ucf_id).first&.name
    end
    tcf_id = myoptions[:task_custom_filter_id].presence
    if tcf_id
      return TaskCustomFilter.where(:id => tcf_id).first&.name
    end
  end

  ###########################################
  # Active Record Validation Methods
  ###########################################

  # before_save callback, adds options={} if options is nil
  def add_empty_options #:nodoc:
    self.options = {} if self.options.nil?
    true
  end

  # For user activity statistics, record the BAC in the Rails logs.
  # A copy is also appended to
  #
  #   RAILS_ROOT/data_dumps/bacs/username.jsonl
  #
  # Usually invoked from after_destroy callback.
  def record_in_rails_log #:nodoc:
    return unless self.id
    status = self.status
    return unless status =~ /^(?:
       Completed | PartiallyCompleted | Failed | InProgress |
       Cancelled | Suspended | InternalError
    )/x # we don't want Scheduled etc that never did anything

    # What to save. All in a single line, no newline.
    json_text = self.attributes.to_json

    # Log in JSON archive file
    if File.directory?(Rails.root + "data_dumps/bacs")
      username  = self.user.login
      File.open(Rails.root + "data_dumps/bacs/#{username}.jsonl","a") do |fh|
        fh.write(json_text + "\n")
      end
    end

    # Log in Rails; this might raise an exception if
    # the destory happens in a BackgroundActivityWorker because
    # they don't have a Rails.logger
    Rails.logger.info "Destroyed BackgroundActivity: #{json_text}"

  rescue
    Rails.logger.error("Cannot log #{self.type} #{self.id}") rescue nil
  end

  def status_is_correct #:nodoc:
    return true if ALL_STATUS.include?(self.status)
    self.errors.add(:status, 'is not acceptable')
    throw :abort
  end

  def repeat_is_correct #:nodoc:
    self.repeat='one_shot' if self.repeat.blank?
    repeat_error = ->(message) { self.errors.add(:repeat, message) }
    match = REPEAT_REGEXES.detect { |r| m=r.match(self.repeat) and break m }
    repeat_error.('is not valid') if ! match

    if match && match.length == 3 # for start+NNN
      repeat_minutes = match[2]
      repeat_error.('has an invalid start+NNN minutes') if repeat_minutes.to_i < 10 || repeat_minutes.to_i > 10080
    end

    if match && match.length == 4 # for all the keyword@HH:MM
      hour, min = match[2], match[3]
      repeat_error.('has an invalid hour') if hour !~ /[01][0-9]|2[0123]/
      repeat_error.('has invalid minutes') if min !~ /[012345][0-9]/
    end

    throw :abort if self.errors.count > 0
    true
  end

  def items_is_array #:nodoc:
    return true if self.items.is_a?(Array)
    self.errors.add(:items, 'is not an array')
    throw :abort
  end

  #########################################################
  # Callbacks And Validators That Can be Used By Subclasses
  #########################################################

  # Callback that subclasses can invoke as a before_save
  # to verify that the background activity is configured to run on a bourreau
  def must_be_on_bourreau!
    return true if Bourreau.where(:id => self.remote_resource_id).exists?
    self.errors.add(:remote_resource_id, 'is not a Bourreau')
    throw :abort
  end

  # Callback that subclasses can invoke as a before_save
  # to verify that the background activity is configured to run on a portal
  def must_be_on_portal!
    return true if BrainPortal.where(:id => self.remote_resource_id).exists?
    self.errors.add(:remote_resource_id, 'is not a BrainPortal')
    throw :abort
  end

  # Class validator. A subclass can make sure
  # the objects contains a :key in the options attribute
  # with a directive like this:
  #
  #    validates_bac_presence_of_option :key
  #
  # If the key is not present, will add an error to
  # the :options attribute
  def self.validates_bac_presence_of_option(*keys)
    keys.each do |key| # symbols
      validate { |bac| bac.options_have!(key) } # closure on key
    end
  end

  # This is similar to validates_bac_presence_of_option but
  # it will apply its validation rules only when the
  # BAC object is configured for dynamic items. Otherwise
  # tha validation is ignored.
  def self.validates_dynamic_bac_presence_of_option(*keys)
    keys.each do |key| # symbols
      validate { |bac| dynamic_and_options_have!(key) } # closure on key
    end
  end

  def options_have!(key) #:nodoc:
    opts = self.options || {}
    return true if opts[key].present?
    self.errors.add(:options, "is missing #{key.to_s.humanize}")
    false
  end

  def dynamic_and_options_have!(key) #:nodoc:
    return true if ! is_configured_for_dynamic_items?
    options_have!(key)
  end

end

