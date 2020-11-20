
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

#ActionMailer subclass for sending system e-mails.
class CbrainMailer < BaseMailer

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def service_name
    "CBRAIN"
  end

  def cbrain_message(*args) #:nodoc:
    Rails.logger.warn "DEPRECATED: Warning: Method #{self.class}#cbrain_message() should be replaced by general_message() instead."
    self.class.general_message(*args) # we need to re-post the args to the class method
  end

  private

  def build_from #:nodoc:
    RemoteResource.current_resource.system_from_email.presence.try(:strip) || super
  end

  def support_email #:nodoc:
    RemoteResource.current_resource.support_email.presence.try(:strip) || super
  end

  def external_url #:nodoc:
    RemoteResource.current_resource.site_url_prefix.presence.try(:strip) || super
  end

  def override_delivery_options #:nodoc:
    RemoteResource.current_resource.email_delivery_options.presence.try(:strip) || super
  end

end
