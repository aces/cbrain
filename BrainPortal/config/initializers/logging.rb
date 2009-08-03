
#
# CBRAIN Project
#
# CBRAIN extensions for logging information about ANY
# object in the DB, as long as they have an 'id' field.
# Note that if the object being logged is an ActiveRecord,
# then the callback after_destroy() will clean up the
# logger object too.
#
# Original author: Pierre Rioux
#
# $Id$
#

module ActRecLog

  Revision_info = "$Id$"

  # Add a log message to the CBRAIN logging system
  # The first time a message is created, some revision
  # information about the current active record class
  # will be added to the top of the log.
  def addlog(message)
    begin
      arl = active_record_log_find_or_create
      return false unless arl
      log = arl.log
      log = "" if log.blank?
      lines = message.split(/\s*\n/)
      lines.pop while lines.size > 0 && lines[-1] == ""
  
      message = lines.join("\n") + "\n"
      log += Time.now.strftime("[%Y-%m-%d %H:%M:%S] ") + message
      arl.update_attributes( { :log => log } )
    rescue
      false
    end
  end

  # Creates a custom message with info about the context
  # where this method is called; the +context+ argument
  # can be any object or class, and its revision_info
  # will be extracted for the final message. Optionally,
  # you can add some more text to the end of the log entry.
  #
  # The end result of using this method on an active
  # record +obj+ from the method xyz() of class +Abcd+,
  # like this:
  #
  #     obj.addlog_context(self,"hello")
  #
  # is a log entry like this one:
  #
  #     "Abcd xyz() revision 123 prioux 2009-05-23 hello"
  def addlog_context(context,message=nil)
    prev_level     = caller[0]
    calling_method = prev_level.match(/in `(.*)'/) ? ($1 + "()") : "unknown()"

    class_name     = context.class.to_s
    class_name     = context.to_s if class_name == "Class"
    rev_info       = context.revision_info
    pretty_info    = rev_info.svn_id_pretty_rev_author_date
 
    full_message   = "#{class_name} #{calling_method} revision #{pretty_info}"
    full_message   += " #{message}" unless message.blank?
    self.addlog(full_message)
  end

  # Creates a custom message with the revision info
  # about an object or class, supplied as the first
  # argument. Its revision_info will be extracted for
  # the final message. Optionally, you can add some
  # more text to the end of the log entry.
  #
  # The end result of using this method on an active
  # record +obj+ with the class +Abcd+ in argument,
  # like this:
  #
  #     obj.addlog_revinfo(Abcd,"hello")
  #
  # is a log entry like this one:
  #
  #     "Abcd revision 123 prioux 2009-05-23 hello"
  def addlog_revinfo(anobject,message=nil)
    class_name     = anobject.class.to_s
    class_name     = anobject.to_s if class_name == "Class"
    rev_info       = anobject.revision_info
    pretty_info    = rev_info.svn_id_pretty_rev_author_date
 
    full_message   = "#{class_name} revision #{pretty_info}"
    full_message   += " #{message}" unless message.blank?
    self.addlog(full_message)
  end

  # Gets the log for the current active record;
  # this is a single long string with embedded newlines.
  def getlog
    arl = active_record_log
    return nil unless arl
    arl.log
  end

  protected

  def active_record_log #:nodoc
    myid    = self.id
    myclass = self.class.to_s
    return nil unless myid
    ActiveRecordLog.find(
       :first,
       :conditions => { :ar_id => myid, :ar_class => myclass }
    )
  end

  def active_record_log_find_or_create #:nodoc:
    arl = active_record_log
    return arl if arl
    
    myid    = self.id
    myclass = self.class.to_s
    return nil unless myid
    message = Time.now.strftime("[%Y-%m-%d %H:%M:%S] ") + "#{myclass} revision " +
              self.revision_info.svn_id_pretty_rev_author_date + "\n"

    arl = ActiveRecordLog.create( :ar_id    => myid,
                                  :ar_class => myclass,
                                  :log      => message )
    arl
  end

end

class ActiveRecord::Base
  include ActRecLog

  after_destroy :destroy_log

  # Destroy the log associated with an active_record
  # This is usually called as a callback when the
  # record is destroyed.
  def destroy_log
    return true if self.is_a?(ActiveRecordLog)
    arl = self.active_record_log
    return true unless arl
    arl.destroy_without_callbacks
    true
  end
end

class ActiveResource::Base
  include ActRecLog
end
