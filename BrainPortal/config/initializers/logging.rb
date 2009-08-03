
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

  def getlog
    arl = active_record_log
    return nil unless arl
    arl.log
  end

  def active_record_log
    myid    = self.id
    myclass = self.class.to_s
    return nil unless myid
    ActiveRecordLog.find(
       :first,
       :conditions => { :ar_id => myid, :ar_class => myclass }
    )
  end

  def active_record_log_find_or_create
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

  def destroy_log
    return if self.is_a?(ActiveRecordLog)
    arl = active_record_log
    return unless arl
    arl.destroy_without_callbacks
  end
end

class ActiveResource::Base
  include ActRecLog
end
