
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

# Helper for logging in using Globus identity stuff
module GlobusHelpers

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # GLOBUS authentication URL constants
  # Maybe should be made configurable.
  GLOBUS_AUTHORIZE_URI = "https://auth.globus.org/v2/oauth2/authorize" # will be issued a GET with params
  GLOBUS_TOKEN_URI     = "https://auth.globus.org/v2/oauth2/token"     # will be issued a POST with a single code

  # Returns the URI to send users to the GLOBUS authentication page.
  # The parameter globus_action_url should be the URL to the controller
  # action here in CBRAIN that will received the POST response.
  def globus_login_uri(globus_action_url)
    return nil if     api_request?
    return nil unless globus_auth_configured?

    # Create the URI to authenticate with GLOBUS
    globus_params = {
      :client_id     => globus_client_id,
      :response_type => 'code',
      :scope         => "urn:globus:auth:scope:auth.globus.org:view_identities openid email profile",
      :redirect_uri  => globus_action_url, # generated from Rails routes
      :state         => globus_current_state, # method is below
    }
    GLOBUS_AUTHORIZE_URI + '?' + globus_params.to_query
  end

  def globus_fetch_token(code, globus_action_url)
    # Query Globus; this returns all the info we need at the same time.
    auth_header = globus_basic_auth_header # method is below
    response = Typhoeus.post(GLOBUS_TOKEN_URI,
      :body   => {
                   :code          => code,
                   :redirect_uri  => globus_action_url,
                   :grant_type    => 'authorization_code',
                 },
      :headers => { :Accept       => 'application/json',
                    :Authorization => auth_header,
                  }
    )

    # Parse the response
    body         = response.response_body
    json         = JSON.parse(body)
    jwt_id_token = json["id_token"]
    identity_struct, _ = JWT.decode(jwt_id_token, nil, false)

    return identity_struct
  rescue => ex
    Rails.logger.error "GLOBUS token request failed: #{ex.class} #{ex.message}"
    return nil
  end

  # Returns the value for the Authorization header
  # when doing the client authentication.
  #
  #  "Basic 1745djfuebwifh37236djdf74.etc.etc"
  def globus_basic_auth_header
    client_id     = globus_client_id
    client_secret = globus_client_secret
    "Basic " + Base64.strict_encode64("#{client_id}:#{client_secret}")
  end

  # Returns a string that should stay constants during the entire
  # globus negotiations. The current Rails session_id, encoded, will do
  # the trick. The Rails session is maintained by a cookie already
  # created and maintained, at this point.
  def globus_current_state
    Digest::MD5.hexdigest( request.session_options[:id] )
  end

  # Return the registered globus endpoint client ID.
  # This value must be configured by the CBRAIN admin
  # in the meta data of the portal. Returns nil if unset.
  def globus_client_id
    myself = RemoteResource.current_resource
    myself.meta[:globus_client_id].presence.try(:strip)
  end

  # Return the registered globus endpoint client secret.
  # This value must be configured by the CBRAIN admin
  # in the meta data of the portal. Returns nil if unset.
  def globus_client_secret
    myself = RemoteResource.current_resource
    myself.meta[:globus_client_secret].presence.try(:strip)
  end

  # Returns true if the CBRAIN system is configured for
  # globus auth.
  def globus_auth_configured?
    myself   = RemoteResource.current_resource
    site_uri = myself.site_url_prefix.presence
    # Three conditions: site uri, client ID, client secret.
    return false if ! site_uri
    return false if ! globus_client_id
    return false if ! globus_client_secret
    true
  end

  # Record the globus identity for the current user.
  # (This maybe should be made into a User model method)
  def record_globus_identity(identity)
    provider_id   = identity['identity_provider']              || cb_error("Globus: No identity provider")
    provider_name = identity['identity_provider_display_name'] || cb_error("Globus: No identity provider name")
    pref_username = identity['preferred_username']             || cb_error("Globus: No preferred username")

    # Special case for ORCID, because we already have fields for that provider
    if provider_name == 'ORCID'
      orcid = pref_username.sub(/@.*/, "")
      current_user.meta['orcid'] = orcid
      current_user.addlog("Linked to ORCID identity: '#{orcid}' through Globus")
      return
    end

    current_user.meta[:globus_provider_id]        = provider_id
    current_user.meta[:globus_provider_name]      = provider_name # used in show page
    current_user.meta[:globus_preferred_username] = pref_username
    current_user.addlog("Linked to Globus identity: '#{pref_username}' on provider '#{provider_name}'")
  end

  # Removes the recorded globus identity for +user+
  def unlink_globus_identity(user)
    current_user.meta[:globus_provider_id]        = nil
    current_user.meta[:globus_provider_name]      = nil
    current_user.meta[:globus_preferred_username] = nil
    current_user.addlog("Unlinked Globus identity")
  end

  # Given a globus identity structure, find the user
  # that matches it and activate the session for that user.
  # Returns the user object if found; returns a string error message otherwise.
  def find_user_with_globus_identity(identity)
    provider_id   = identity['identity_provider']              || cb_error("Globus: No identity provider")
    provider_name = identity['identity_provider_display_name'] || cb_error("Globus: No identity provider name")
    pref_username = identity['preferred_username']             || cb_error("Globus: No preferred username")

    # Special case for ORCID, because we already have fields for that provider
    if provider_name == 'ORCID'
      orcid = pref_username.sub(/@.*/, "")
      users = User.find_all_by_meta_data(:orcid, orcid)
    else # All other globus providers
      # We need a user which match both the preferred username and provider_id
      users = User.find_all_by_meta_data(:globus_preferred_username, pref_username)
        .to_a
        .select { |user| user.meta[:globus_provider_id] == provider_id }
    end

    if users.size == 0
      Rails.logger.error "GLOBUS warning: no CBRAIN accounts found for identity '#{pref_username}' on provider '#{provider_name}'"
      return "No CBRAIN user matches your Globus identity. Create a CBRAIN account or link your existing CBRAIN account to your Globus provider."
    end

    if users.size > 1
      Rails.logger.error "GLOBUS error: multiple CBRAIN accounts found for identity '#{pref_username}' on provider '#{provider_name}'"
      return "Several CBRAIN user accounts match your Globus identity. Please contact the CBRAIN admins."
    end

    # The one lucky user
    return users.first
  end

end
