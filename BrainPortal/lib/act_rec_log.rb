
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

# CBRAIN extensions for logging information about ANY
# object in the DB, as long as they have an 'id' field.
# Note that if the object being logged is an ActiveRecord,
# then the callback after_destroy() will clean up the
# logger object too. See the module ActRecLog for more
# information.
#
# Original author: Pierre Rioux

# = CBRAIN Data Tracking API
#
# It's important operations performed by CBRAIN users be tracked
# carefully. Whenever a data file is processed trough a scientific tool, we
# need to record somewhere that this was performed, and the record should
# contain not only the name of the tool but also its revision number,
# the revision numbers of other modules involved, and if possible what
# parameters were used. The same information should be recorded for the
# output files produced by the tools, too.
#
# === The 'active_record_log' Table
#
# As of subversion revision 393 of CBRAIN, a new database table will
# provide the data tracking facility. Although it is a normal Rails
# ActiveRecord table, it is designed to store objects related to ANY other
# ActiveRecords on the system, without using the Rails linking mechanism
# (those that are defined with 'belongs_to', 'has_many', 'has_one' etc).
# This table and its records are NOT expected to be ever accessed by CBRAIN
# programmers directly, instead a simple API has been added to the lowest
# level of the ActiveRecord class hierarchy, ActiveRecord::Base.
#
# === The new ActiveRecord methods
#
# There are four instance methods in the data tracking API. These
# four methods are available for ANY ActiveRecord object 'obj' on the
# system. They are:
#
#     obj.addlog(message)
#     obj.addlog_context(ctx,message=nil)
#     obj.addlog_revinfo(data,message=nil)
#     obj.getlog()
#
# All of these manipulate a simple text file that is associated precisely
# and uniquely with the object on which the method is called. The text
# file is stored as a single long string with embedded newlines.
# Here
# is how each of these method work, and in what situation you should use
# them.
#
# * obj.addlog(message)
#
# This is the simplest logging method. It simply appends the message
# string to the obj's current log. If the message is the very first
# message created for that object, then addlog will automatically
# prepend a line logging the class and revision information for
# the object 'obj'. The format of the appended line is:
#
#   [2009-08-03 17:32:19] message
#
# * obj.addlog_context(ctx,message=nil)
#
# This method works like addlog(), but also prepends the optional
# message with callback information and revision information
# associated with 'ctx'. This method is meant to add a log
# entry describing where the program IS at the current moment,
# so usually and almost systematically, you should use 'self'
# as the ctx argument. The logged line will look like this:
#
#   [2009-08-03 17:32:19] ctxclass currentmethod() ctxrevinfo message
#
# * obj.addlog_revinfo(data,message=nil)
#
# This message works like addlog(), but also prepends the optional
# message with revision information about the 'data', which can be
# almost anything (an object, or a class, or anything that responds
# to the CBRAIN 'revision_info' method). This method is meant to
# add a log entry describing information about another resource (the
# 'data') that is currently being used for processing this object.
# The logged line will look like this:
#
#   [2009-08-03 17:32:19] dataclass datarevinfo message
#
# * obj.getlog()
#
# Returns the current log as a single long string with embedded
# newlines. Will return nil if no log yet exists for the object.
#
# Note that along with these new methods, some ActiveRecord callbacks have
# been defined behind the scene such that any ActiveRecord object being
# destroy()ed will trigger the destruction of its associated log.
#
# === Examples
#
# Here's a complete example that show in which situations all three addlog()
# methods should be called, and what the resulting logs will look like.
#
# Let's suppose we have a subroutine do_analysis() that receives a userfile
# 'myfile', does some processing on it using the methods 'shred' of the
# data processing object 'myshred' (of class 'Shredder'), which returns a
# new userfile 'resultfile'. The plain pseudo code looks like this (the
# content of two ruby files 'processor.rb' and 'shredder.rb' are shown):
#
#   class Processor
#     Revision_info="SId: processor.rb 123 2009-07-30 16:55:47Z prioux S"
#     def do_analysis(myfile,myshred)
#       resultfile = myshred.shred(myfile)
#       return resultfile
#     end
#   end
#
#   class Shredder
#     Revision_info="SId: shredder.rb 424 2009-08-30 13:25:12Z prioux S"
#     def shred(file)
#       resfile = Dosome.thing(file)
#       return resfile
#     end
#   end
#
# We want to improve the code to record the information about all these steps
# and methods. Let's just sprinkle addlog() calls here and there:
#
#   class Processor
#     Revision_info="SId: processor.rb 123 2009-07-30 16:55:47Z prioux S"
#     def do_analysis(myfile,myshred)
#       myfile.addlog_context(self,"Sending to Shredder")     #1
#       resultfile = myshred.shred(myfile)
#       resultfile.addlog_context(self,"Created by Shredder") #2
#       return resultfile
#     end
#   end
#
#   class Shredder
#     Revision_info="SId: shredder.rb 424 2009-08-30 13:25:12Z prioux S"
#     def shred(file)
#       file.addlog_context(self)                             #3
#       file.addlog_revinfo(Dosome)                           #4
#       file.addlog("Processed by method 'thing')             #5
#       resfile = Dosome.thing(file)
#       resfile.addlog_context(self)                          #6
#       return resfile
#     end
#   end
#
# The resulting logfiles associated with 'myfile' and 'resultfile'
# now contain a great deal of information about what happened to them.
# Here's the log for 'myfile'; the hashed numbers before the date stamp
# indicate which line of code created which log entry.
#
#   #1 [2009-08-03 17:32:19] SingleFile revision 322 tsherif 2009-07-13
#   #1 [2009-08-03 17:32:19] Processor do_analysis() revision 123 prioux 2009-07-30 Sending to Shredder
#   #3 [2009-08-03 17:32:19] Shredder shred() revision 424 prioux 2009-08-30
#   #4 [2009-08-03 17:32:19] Dosome revision 66 prioux 2009-04-21
#   #5 [2009-08-03 17:32:19] Processed by method 'thing'
#
# And here's the log for 'resultfile'.
#
#   #6 [2009-08-03 17:32:19] SingleFile revision 322 tsherif 2009-07-13
#   #6 [2009-08-03 17:32:19] Shredder shred() revision 424 prioux 2009-08-30
#   #2 [2009-08-03 17:32:19] Processor do_analysis() revision 123 prioux 2009-07-30 Created by Shredder
#
module ActRecLog

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  ADDLOG_DEFAULT_ATTRIBUTES_LOGGING = %w(
       name type time_zone online
       user_id group_id site_id
       read_only size
       data_provider_id bourreau_id tool_id tool_config_id
       description
  )

  # Check that the the class this module is being included into is a valid one.
  def self.included(includer) #:nodoc:
    unless includer <= ActiveRecord::Base
      raise "#{includer} is not an ActiveRecord model. The ActRecLog module cannot be used with it."
    end

    includer.class_eval do
      extend ClassMethods
      after_create  :propagate_tmp_log
      after_destroy :destroy_log
    end
  end

  module ClassMethods #:nodoc:
    # None for the moment.
  end

  # Add a log +message+ to the CBRAIN logging system
  # The first time a message is created, some revision
  # information about the current ActiveRecord class
  # will be added to the top of the log.
  def addlog(message, options = { :no_caller => true })
    return true  if self.is_a?(ActiveRecordLog) || self.is_a?(MetaDataStore)
    use_internal = self.new_record? || self.id.blank?
    begin
      unless use_internal
        arl = active_record_log_find_or_create
        return false unless arl
      end

      callerlevel    = options[:caller_level] || 0
      calling_info   = caller[callerlevel]
      calling_method = options[:prefix] || ( calling_info.match(/in `(.*)'/) ? ($1 + "() ") : "unknown() " )
      calling_method = "" if options[:no_caller]
      calling_method.sub!(/(block|rescue).*? in /, "")

      log = use_internal ? @tmp_internal_log : arl.log
      log = "" if log.blank?
      lines = message.split(/\s*\n/)
      lines.pop while lines.size > 0 && lines[-1] == ""

      message = lines.join("\n") + "\n"
      log += Time.zone.now.strftime("[%Y-%m-%d %H:%M:%S %Z] ") + calling_method + message
      while log.size > 65500 && log =~ /\n/   # TODO: archive ?
        log.sub!(/\A[^\n]*\n/,"")
      end
      if use_internal
        @tmp_internal_log = log
      else
        arl.update_attributes( { :log => log } )
      end
    rescue
      # puts_green "EX: #{ex.class}: #{ex.message}\n#{ex.backtrace.join("\n")}"
      false
    end
  end

  # Creates a custom log entry with info about the context
  # where this method is called; the +context+ argument
  # can be any object or class, and its revision_info
  # will be extracted for the final message. Optionally,
  # you can add some more text to the end of the log entry.
  #
  # Using this method on an ActiveRecord +obj+ from the
  # method xyz() of class +Abcd+, like this:
  #
  #     obj.addlog_context(self,"hello")
  #
  # results is a log entry like this one:
  #
  #     "Abcd xyz() revision 123 prioux 2009-05-23 hello"
  #
  # A third optional argument +caller_level+ indicates
  # how many levels of calling context to go back to find the method
  # name to display (the default is 0, which means the method
  # where you call addlog_context() itself).
  def addlog_context(context, message=nil, caller_level=0)
    return true  if self.is_a?(ActiveRecordLog) || self.is_a?(MetaDataStore)
    class_name     = context.class.to_s
    class_name     = context.to_s if class_name == "Class"
    rev_info       = context.revision_info
    pretty_info    = rev_info.short_commit

    full_message   = "#{class_name} rev. #{pretty_info}"
    full_message  += " #{message}" unless message.blank?
    self.addlog(full_message, :caller_level => caller_level + 1)
  end

  # Creates a custom log entry with the revision info
  # about +anobject+, which is any object or class, supplied as
  # the first argument. Its revision_info will be extracted for
  # the final message. Optionally, you can add some
  # more text to the end of the log entry.
  #
  # Using this method on an ActiveRecord
  # +obj+ with the class +Abcd+ in argument,
  # like this:
  #
  #     obj.addlog_revinfo(Abcd,"hello")
  #
  # results is a log entry like this one:
  #
  #     "Abcd revision 123 prioux 2009-05-23 hello"
  def addlog_revinfo(anobject, message=nil, caller_level=0)
    return true  if self.is_a?(ActiveRecordLog) || self.is_a?(MetaDataStore)
    class_name     = anobject.class.to_s
    class_name     = anobject.to_s if class_name == "Class"
    rev_info       = anobject.revision_info
    pretty_info    = rev_info.short_commit

    full_message   = "#{class_name} rev. #{pretty_info}"
    full_message   += " #{message}" unless message.blank?
    self.addlog(full_message, :caller_level => caller_level + 1)
  end

  # This method records in the object's log a list of
  # all currenly pending changes to the object's attribute,
  # if any. +by_user+ is an optional User object indicating
  # who made the changes. +white_list+ is a list of attributes
  # to look for; to this list will be added a standard hardcoded
  # set of attributes, defined in the constant
  # ADDLOG_DEFAULT_ATTRIBUTES_LOGGING
  def addlog_changed_attributes(by_user = nil, white_list = [], caller_level=0)
    return true if self.is_a?(ActiveRecordLog) || self.is_a?(MetaDataStore)
    return true unless self.changed?
    ext_white_list = white_list + ADDLOG_DEFAULT_ATTRIBUTES_LOGGING
    by_user_mess = by_user.present? ? " by #{by_user.login}" : ""
    self.changed_attributes.each do |att,old|
      next unless ext_white_list.any? { |v| v.to_s == att.to_s }
      att_type = self.class.columns_hash[att.to_s].type rescue :string # ActiveRecord type, e.g. :boolean, or :string
      new = self.read_attribute(att)
      new = !(new.blank? || new.to_s == "false" || new.to_s == "0") if att_type == :boolean # prettier, since we can write "" to a boolean field
      old = old.to_s
      new = new.to_s
      next if new == old # well, it seems it's the same anyway; happens when writing "" to replace a 'false'
      if att_type == :boolean
        message = "is now #{new}"
      elsif self.class.serialized_attributes[att]
        message = "(serialized) size(#{old.size} -> #{new.size})"
      elsif old.size > 60 || new.size > 60
        message = ": size(#{old.size} -> #{new.size})"
      else
        if att =~ /\A(\w+)_id\z/
          model = Regexp.last_match[1].classify.constantize rescue nil
          if model
            oldobj = model.find_by_id(old) rescue nil
            newobj = model.find_by_id(new) rescue nil
            old = oldobj.try(:name) || oldobj.try(:login) || old
            new = newobj.try(:name) || newobj.try(:login) || new
          end
        end
        if att.to_sym == :type
          old = "#{old} rev. #{old.constantize.revision_info.self_update.short_commit}" rescue "#{old} rev. exception"
          new = "#{new} rev. #{new.constantize.revision_info.self_update.short_commit}" rescue "#{new} rev. exception"
        end
        old = '(nil)'   if old.nil?
        new = '(nil)'   if new.nil?
        old = '""'      if old == ''
        new = '""'      if new == ''
        old = '(blank)' if old.blank?
        new = '(blank)' if new.blank?
        message = ": value(#{old} -> #{new})"
      end
      self.addlog("Updated#{by_user_mess}: #{att} #{message}", :caller_level => caller_level + 3)
    end
    true
  end

  # This method is just like update_attributes(), but also logs
  # the changed attributes using addlog_changed_attributes().
  # The method returns false if the object could not be updated
  # or is invalid.
  #
  # The method doesn't have to be the only one to change the attributes
  # we want logged; you can change the attributes beforehand using
  # standard ActiveRecord assignements, and then call the method
  # with an empty hash to get them logged and saved.
  #
  # The +by_user+ and +white_list+ arguments are passed to
  # addlog_changed_attributes() and are documented there.
  def update_attributes_with_logging(new_attributes={}, by_user=nil, white_list=[], caller_level=0)
    self.attributes = new_attributes if new_attributes.present?
    return false unless self.errors.empty? && self.valid?
    self.addlog_changed_attributes(by_user,white_list,caller_level+1)
    self.save(:validate => false)
  end

  # This method is a bit like update_attributes_with_logging, but
  # no new attributes are expected as argument. It is often used
  # as a replacement for save() when the attributes have already been
  # been changed.
  def save_with_logging(by_user=nil, white_list=[], caller_level=0)
    self.update_attributes_with_logging({}, by_user, white_list, caller_level + 1)
  end

  # This method takes two lists +oldlist and +newlist+ of ActiveRecord object
  # of type +model+ (or just their IDs) and compare them, logging
  # he changes in the lists. +message+ should be a description of the
  # meaning of these lists. Example:
  #
  #   mysite.addlog_object_list_updated("Managers", User, [1,2,3], [2,3,4,5], adminuser, :login)
  #
  # will add a log entry like this
  #
  #   Managers updated by adminuser: Removed: login1
  #   Managers uddated by adminuser: Added: login4, login5
  def addlog_object_list_updated(message, model, oldlist, newlist, by_user=nil, name_method=:name, caller_level = 0)
    klass = model < ActiveRecord::Base ? model : model.constantize
    oldlist = Array(oldlist)
    newlist = Array(newlist)
    # this method handles mixed arrays of IDs or objects
    oldlist_part = oldlist.hashed_partition { |x| x.is_a?(ActiveRecord::Base) ? :obj : :id }
    newlist_part = newlist.hashed_partition { |x| x.is_a?(ActiveRecord::Base) ? :obj : :id }
    oldlist = ((oldlist_part[:obj] || []) + (oldlist_part[:id] ? klass.find_all_by_id(oldlist_part[:id]) : [])).uniq
    newlist = ((newlist_part[:obj] || []) + (newlist_part[:id] ? klass.find_all_by_id(newlist_part[:id]) : [])).uniq
    added     = newlist - oldlist
    removed   = oldlist - newlist
    by_user_mess = by_user.present? ? " by #{by_user.login}" : ""
    mess = "#{message} updated#{by_user_mess}:"
    if removed.present?
      self.addlog("#{mess} Removed: #{removed.map(&name_method).join(", ")}")
    end
    if added.present?
      self.addlog("#{mess} Added: #{added.map(&name_method).join(", ")}")
    end
    true
  rescue => ex
    puts_red "Exception in addlog_object_list_updated: #{ex.class} #{ex.message}\n#{ex.backtrace.join("\n")}"
  end

  # Gets the log for the current ActiveRecord;
  # this is a single long string with embedded newlines.
  def getlog
    return nil if self.is_a?(ActiveRecordLog) || self.is_a?(MetaDataStore)
    return @tmp_internal_log if self.new_record? || self.id.blank?
    arl = active_record_log
    return nil unless arl
    arl.log
  end

  # This appends the raw +text+ to the current
  # ActiveRecord's log, without any reformating.
  # Use addlog() for normal operation; this method
  # is rarely used in normal situations.
  def raw_append_log(text)
    return false if self.is_a?(ActiveRecordLog) || self.is_a?(MetaDataStore)
    if self.new_record? || self.id.blank?
      @tmp_internal_log ||= ""
      @tmp_internal_log += text
      return true
    end
    return false if self.id.blank?
    arl = active_record_log_find_or_create
    log = arl.log + text
    while log.size > 65500 && log =~ /\n/   # TODO: archive ?
      log.sub!(/^[^\n]*\n/,"")
    end
    arl.update_attributes( { :log => log } )
  end

  # Destroy the log associated with an ActiveRecord.
  # This is usually called automatically as a +after_destroy+
  # callback when the record is destroyed, but it can be
  # called manually too.
  def destroy_log
    return true if self.is_a?(ActiveRecordLog) || self.is_a?(MetaDataStore)
    if self.new_record? || self.id.blank?
      @tmp_internal_log = ""
      return true
    end
    arl = self.active_record_log
    return true unless arl
    ActiveRecordLog.delete(arl.id) # was: destroy_without_callbacks
    true
  end

  # Logs have been temporarily saved to
  # an internal variable when the object
  # doesn't yet have an ID; this method
  # sends that tmp log to the real log
  # record. It is usually called automatically
  # as a after_create() callback.
  def propagate_tmp_log #:nodoc:
    return false if self.is_a?(ActiveRecordLog) || self.is_a?(MetaDataStore)
    return false if self.new_record? || self.id.blank?
    return true  if @tmp_internal_log.blank?
    arl = active_record_log_find_or_create
    log = (arl.log || "") + @tmp_internal_log.to_s
    arl.update_attributes( { :log => log } )
    @tmp_internal_log = ""
    true
  end

  protected

  def active_record_log #:nodoc:
    return nil if self.is_a?(ActiveRecordLog) || self.is_a?(MetaDataStore)
    myid    = self.id
    mytable = self.class.table_name
    return nil if myid.blank?
    ActiveRecordLog.where( :ar_id => myid, :ar_table_name => mytable ).first
  end

  def active_record_log_find_or_create #:nodoc:
    return nil if self.is_a?(ActiveRecordLog) || self.is_a?(MetaDataStore)
    arl = active_record_log
    return arl if arl

    myid    = self.id
    mytable = self.class.table_name
    return nil unless myid
    message = Time.zone.now.strftime("[%Y-%m-%d %H:%M:%S %Z] ") + "#{self.class} revision " +
              self.revision_info.format() + "\n"

    arl = ActiveRecordLog.create( :ar_id         => myid,
                                  :ar_table_name => mytable,
                                  :log           => message )
    arl
  end

end

