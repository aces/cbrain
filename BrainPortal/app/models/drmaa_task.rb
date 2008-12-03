
#
# CBRAIN Project
#
# DrmaaTask models as ActiveResource
#
# Original author: Pierre Rioux
#
# $Id$
#

class DrmaaTask < ActiveResource::Base

  Revision_info="$Id$"

  self.site = CBRAIN::Bourreau_task_resource_URL

  # This is an overidde of the ActiveResource methiod
  # used to instanciate objects received from the XML
  # stream; this methods will use the attribute 'type',
  # if available, to select the class of the object being
  # reconstructed.
  def self.instantiate_record(record, prefix_options = {})
    if record.empty? || ! record.has_key?("type")
      super(record,prefix_options)
    else
      subtype = record.delete("type")
      subclass = Class.const_get(subtype)
      returning subclass.new(record) do |resource|
        resource.prefix_options = prefix_options
      end
    end
  end

end

