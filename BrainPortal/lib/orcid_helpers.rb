
#
# NeuroHub Project
#
# Copyright (C) 2021
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

# Helper for Neurohub interface
module OrcidHelpers

  # ORCID authentication URL constants
  # Maybe shoudl be made configurable.
  # FIXME TODO currently contains sandbox URI ; remove 'sandbox.' once
  # dev testing is finished
  ORCID_AUTHORIZE_URI = "https://sandbox.orcid.org/oauth/authorize" # will be issued a GET with params
  ORCID_TOKEN_URI     = "https://sandbox.orcid.org/oauth/token"     # will be issued a POST with a single code

  def orcid_login_uri
    myself              = RemoteResource.current_resource

    # The following three values must be configured by the sysadmin
    site_uri            = myself.site_url_prefix.presence.try(:strip)
    orcid_client_id     = myself.meta[:orcid_client_id].presence.try(:strip)
    orcid_client_secret = myself.meta[:orcid_client_secret].presence.try(:strip) # not used here but needed later

    # We need all three in order to be allowed to use ORCID
    return nil if site_uri.blank? || orcid_client_id.blank? || orcid_client_secret.blank?

    # Create the URI to authenticate with ORCID
    orcid_params = {
             :client_id     => orcid_client_id,
             :response_type => 'code',
             :scope         => '/authenticate',
             :redirect_uri  => orcid_url, # generated from Rails routes
    }
    ORCID_AUTHORIZE_URI + '?' + orcid_params.to_query
  end

  # shortens ORCID iD by dropping url (possibly distorted)
  def orcid_digits(orcid)
    orcid.to_s[/\d\d\d\d-\d\d\d\d-\d\d\d\d-\d\d\d[\dX]/i]
  end

  # normalizes ORCID iD into the standard/canonical form (the url)
  def orcid_canonize(s)
    "https://orcid.org/#{orcid_digits(s)}" if s.present?
  end

end
