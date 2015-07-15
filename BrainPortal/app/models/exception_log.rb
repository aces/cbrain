
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

# Exception logging class
class ExceptionLog < ActiveRecord::Base

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  belongs_to :user

  serialize :backtrace
  serialize :request
  serialize :request_headers
  serialize :session


  # Create an exception record based on exception, user, current request.
  def self.log_exception(exception, user, request)
    params  = request.params.hide_filtered
    session = request.session
    hdrs    = request.headers.select { |k| k =~ /^[A-Z]/ }

    e                    = self.new
    e.exception_class    = exception.class.to_s
    e.request_controller = params[:controller]
    e.request_action     = params[:action]
    e.request_method     = request.method.to_s.upcase
    e.request_format     = request.format.to_sym.to_s
    e.user_id            = user.try(:id)
    e.message            = exception.message
    e.backtrace          = exception.backtrace
    e.request            = {
                          :url         => "#{request.protocol}#{request.env["HTTP_HOST"]}#{request.fullpath}",
                          :parameters  => params.inspect,
                          :format      => request.format.to_s
                          }
    e.session            = session.to_hash
    e.request_headers    = hdrs
    e.instance_name      = CBRAIN::Instance_Name rescue "(?)"
    e.revision_no        = $CBRAIN_StartTime_Revision
    e.save

    e
  end

  after_find :replace_attributes_too_big
  attr_accessor :truncated_attributes

  def replace_attributes_too_big
    raw = {}
    self.class.serialized_attributes.keys.each do |att|
      att = att.to_sym
      val = self.send(att)
      next unless val.is_a?(String) # when string, something went wrong
      self.send("#{att}=", { :too_long => "the information for \"#{att}\" was too long to fit in the DB..." })
      raw[att] = val # so we can still display it in the interface
    end
    self.truncated_attributes = raw
    true
  end

end
