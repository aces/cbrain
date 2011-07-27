
#
# CBRAIN Project
#
# Serializer task model
#
# Original author: Pierre Rioux
#
# $Id$
#

# A subclass of PortalTask to serialize other tasks.
class CbrainTask::CbSerializer < PortalTask

  Revision_info=CbrainFileRevision[__FILE__]

  def self.properties #:nodoc:
    { :no_presets => true }
  end

  # Disabled, not necessary, and costly a little.
  # I want to keep the code around for future use, though.
  #def pretty_name #:nodoc:
  #  prereqs      = self.prerequisites  || {}
  #  for_setup    = prereqs[:for_setup] || {}
  #  ttids        = for_setup.keys   #  [ "T123", "T343" etc ]
  #  tids         = ttids.map { |ttid| ttid[1,999].to_i }
  #  prereq_tasks = CbrainTask.find_all_by_id(tids)
  #  grouped      = prereq_tasks.group_by(&:name)
  #  summary      = ""
  #  grouped.each do |name,tasklist|
  #    summary += ", " if ! summary.blank?
  #    summary += "#{name} x #{tasklist.size}"
  #  end
  #  "Serializer (#{summary})"
  #end

end

