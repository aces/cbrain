
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

# Tracks a background activity job
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

  belongs_to :user
  belongs_to :remote_resource

  ALL_STATUS = %w(
    InProgress Completed PartiallyCompleted Failed InternalError
              Cancelled                   Suspended
    Scheduled CancelledScheduled SuspendedScheduled
  )

  def pretty_name
    self.class.to_s.demodulize + " on #{self.items.size} items"
  end

  def status_is_correct
    return true if ALL_STATUS.include?(self.status)
    self.errors.add(:status, 'is not acceptable')
    throw :abort
  end

  def items_is_array
    return true if self.items.is_a?(Array)
    self.errors.add(:items, 'is not an array')
    throw :abort
  end

  def self.local_new(user_id, items, remote_resource_id=CBRAIN::SelfRemoteResourceId)
    self.new(
      :status             => 'InProgress',
      :user_id            => user_id,
      :items              => Array(items),
      :remote_resource_id => remote_resource_id,
    )
  end

  # Process the next item in the list.
  # This method assumes we've acquired the lock on the record.
  def process_next_item

    return false if self.status != 'InProgress'

    # Find current item
    idx  = self.current_item
    item = self.items[idx]
    return false if item.nil?

    # Callback where a subclass can do some special stuff
    # before the first item.
    begin
      self.before_first_item if idx == 0
    rescue => ex
      self.status = 'InternalError'
      self.save
      return false
    end

    # Main processing handler
    ok,message = nil,nil
    begin
      ok,message = self.process(item)
    rescue => ex
      ok      = false
      message = "#{ex.class}: #{ex.message}"
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

    # Callback where a subclass can do some special stuff
    # after the last item.
    begin
      self.after_last_item if self.current_item >= items.size
    rescue => ex
      self.status = 'InternalError'
      self.save
      return false
    end

    # Return true if there is more to do, potentially
    self.status == 'InProgress'
  end

  def cancel!
    self.update_column(:status, 'Cancelled')          if self.status == 'InProgress'
    self.update_column(:status, 'CancelledScheduled') if self.status == 'Scheduled'
    self.status == 'Cancelled'
  end

  def suspend!
    self.update_column(:status, 'Suspended')          if self.status == 'InProgress'
    self.update_column(:status, 'SuspendedScheduled') if self.status == 'Scheduled'
    self.status == 'Cancelled'
  end

  def unsuspend!
    self.update_column(:status, 'InProgress')         if self.status == 'Suspended'
    self.update_column(:status, 'Scheduled')          if self.status == 'SuspendedScheduled'
    self.status == 'Cancelled'
  end

  def get_lock
    lock_key = self.class.uniq_thread_id
    return true if self.handler_lock == lock_key # I already locked this
    return nil  if self.handler_lock.present? # locked by another process
    self.class.transaction do
      self.lock!(true) # reloads the record
      return nil if self.handler_lock.present?
      self.update_column(:handler_lock, lock_key)
    end
    return true
  rescue => ex
    # couldn't obtain lock
    false
  end

  def remove_lock
    lock_key = self.class.uniq_thread_id
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

  def self.uniq_thread_id
    @shostname        ||= Socket.gethostname.to_s.sub(/\..*/,"") # short hostname
    #@unique_thread_id ||= "#{CBRAIN::CBRAIN_RAILS_APP_NAME}-#{Process.pid}-#{Thread.current.object_id}"
    @unique_thread_id ||= "#{@shostname}-#{Process.pid}-#{Thread.current.object_id}"
  end

  # Note: does not lock first
  def process_next_items_for_duration(time)
    start_at = Time.now
    while (Time.now - start_at) < time
      break if ! self.process_next_item # returns nil if items all processed or status not InProgress
    end
  end

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

  def schedule_dup
    return nil unless self.status == 'Scheduled'
    newbac              = self.dup
    newbac.status       = 'InProgress'
    newbac.handler_lock = nil
    newbac.start_at     = nil
    newbac.repeat       = nil
    newbac.prepare_scheduled_items
    newbac.save
  end

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
      _,nextday,hour,minutes = Rexexp.last_match.to_a

      if nextday == 'tomorrow'
        daystart = DateTime.now.tomorrow.at_beginning_of_day.getlocal
      elsif
        daystart = Date.parse(nextday) # this return a day before or after today
        daystart = DateTime.parse(daystart.to_s + DateTime.now.zone)
      end

      self.start = daystart + hour.to_i.hours + minutes.to_i.minutes
      self.start = self.start + 7.days if self.start < DateTime.now
      return self.save
    end

    # The schedule attribute has a value we don't understand
    self.update_column(:status, 'InternalError')

  end

  # DEBUG ONLY. Not a method that is part of the standard usage.
  def reset!(status = 'InProgress')
    self.status        = status
    self.current_item  = 0
    self.num_successes = 0
    self.num_failures  = 0
    self.messages      = nil
    self.save
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

  # Abtract method. This method is invoked
  # automatically when a BackgroundActivity object
  # is created out of a 'Scheduled' object.
  # This is the place a subclass can prepare the
  # list of items when that list is dynamic.
  def prepare_scheduled_items
    true
  end

  # Abstract method. Invoked by the execution framework
  # just after processing the last item and having
  # changed the status.
  def after_last_item
    true
  end

end

