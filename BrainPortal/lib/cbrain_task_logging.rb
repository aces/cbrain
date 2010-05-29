
#
# CBRAIN Project
#
# Original author: Pierre Rioux
#
# $Id$
#

# Module containing common logging methods for the CbrainTask
# classes used on the BrainPortal and Bourreau side; theses
# methods are meant to be used with ActiveRecord objects
# and behave similarly to those in the ActRecLog module,
# except that the logs are store inside the CbrainTask object's
# :log attribute.
module CbrainTaskLogging

  Revision_info="$Id$"

  ##################################################################
  # Internal Logging Methods
  ##################################################################

  # Record a +message+ in this task's log.
  def addlog(message, options = {})
    log = self.log
    log = "" if log.nil? || log.empty?
    callerlevel    = options[:caller_level] || 0
    calling_info   = caller[callerlevel]
    calling_method = options[:prefix] || ( calling_info.match(/in `(.*)'/) ? ($1 + "() ") : "unknown() " )
    calling_method = "" if options[:no_caller]
    lines = message.split(/\s*\n/)
    lines.pop while lines.size > 0 && lines[-1] == ""
    message = lines.join("\n") + "\n"
    log +=
      Time.now.strftime("[%Y-%m-%d %H:%M:%S] ") + calling_method + message
    self.log = log
  end

  # Compatibility method to let this class
  # act a bit like the other classes extended
  # by the ActRecLog module (see logging.rb).
  # This is necessary because CbrainTask objects
  # have their very own internal embedded log
  # and do NOT use the methods defined by the
  # ActRecLog module.
  def getlog
    self.log
  end

  # Compatibility method to let this class
  # act a bit like the other classes extended
  # by the ActRecLog module (see logging.rb).
  # This is necessary because CbrainTask objects
  # have their very own internal embedded log
  # and do NOT use the methods defined by the
  # ActRecLog module.
  def addlog_context(context,message="")
    prev_level     = caller[0]
    calling_method = prev_level.match(/in `(.*)'/) ? ($1 + "()") : "unknown()"

    class_name     = context.class.to_s
    class_name     = context.to_s if class_name == "Class"
    rev_info       = context.revision_info
    pretty_info    = rev_info.svn_id_pretty_rev_author_date

    full_message   = "#{class_name} #{calling_method} revision #{pretty_info}"
    full_message   += " #{message}" unless message.blank?
    self.addlog(full_message, :no_caller => true )
  end

  # Compatibility method to let this class
  # act a bit like the other classes extended
  # by the ActRecLog module (see logging.rb).
  # This is necessary because CbrainTask objects
  # have their very own internal embedded log
  # and do NOT use the methods defined by the
  # ActRecLog module.
  def addlog_revinfo(anobject,message="")
    class_name     = anobject.class.to_s
    class_name     = anobject.to_s if class_name == "Class"
    rev_info       = anobject.revision_info
    pretty_info    = rev_info.svn_id_pretty_rev_author_date

    full_message   = "#{class_name} revision #{pretty_info}"
    full_message   += " #{message}" unless message.blank?
    self.addlog(full_message, :no_caller => true )
  end

  # Records in the task's log the info about an exception.
  # This happens frequently not only in this code here
  # but also in subclasses, in the Bourreau controller and in
  # the BourreauWorkers, so it's worth having this utility.
  # The method can also be called by CbrainTask programmers.
  def addlog_exception(exception,message="Exception raised:",backtrace_lines=15)
    message = "Exception raised:" if message.blank?
    message.sub!(/[\s:]*$/,":")
    self.addlog("#{message} #{exception.class}: #{exception.message}")
    if backtrace_lines > 0
      backtrace_lines = exception.backtrace.size - 1 if backtrace_lines >= exception.backtrace.size
      exception.backtrace[1..backtrace_lines].each { |m| self.addlog(m) }
    end
  end

end
