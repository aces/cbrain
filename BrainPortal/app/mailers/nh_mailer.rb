
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
class NhMailer < BaseMailer

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def service_name
    "NeuroHub"
  end

  private

  def build_from #:nodoc:
    RemoteResource.current_resource.nh_system_from_email.presence.try(:strip) || super
  end

  def support_email #:nodoc:
    RemoteResource.current_resource.nh_support_email.presence.try(:strip) || super
  end

  def external_url #:nodoc:
    RemoteResource.current_resource.nh_site_url_prefix.presence.try(:strip) || super
  end

  def override_delivery_options #:nodoc:
    RemoteResource.current_resource.nh_email_delivery_options.presence.try(:strip) || super
  end

end
