
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

  # OIDC authentication URL constants
  # Maybe should be made configurable.

  # will be issued a GET with params
  GLOBUS_AUTHORIZE_URI = RemoteResource.current_resource.meta[:oidc_authorize_uri] || "https://auth.globus.org/v2/oauth2/authorize"
  # will be issued a POST with a single code
  GLOBUS_TOKEN_URI     = RemoteResource.current_resource.meta[:oidc_token_uri]     || "https://auth.globus.org/v2/oauth2/token"
  # for pages that provide this link
  GLOBUS_LOGOUT_URI    = RemoteResource.current_resource.meta[:oidc_logout_uri]    || "https://auth.globus.org/v2/web/logout"
 
 
  # Define OIDC scope
  $scope,$oidc_name = !RemoteResource.current_resource.meta[:oidc_client].casecmp?("keycloak") ? 
                        ["urn:globus:auth:scope:auth.globus.org:view_identities openid email profile", "Globus"] : 
                        ["openid email profile", "Keycloak"]


  # Returns the URI to send users to the OIDC authentication page.
  # The parameter globus_action_url should be the URL to the controller
  # action here in CBRAIN that will received the POST response.
  def globus_login_uri(globus_action_url)
    return nil if     api_request?
    return nil unless globus_auth_configured?

    # Create the URI to authenticate with OIDC
    globus_params = {
      :client_id     => globus_client_id,
      :response_type => 'code',
      :scope         => $scope,
      :redirect_uri  => globus_action_url,    # generated from Rails routes
      :state         => globus_current_state, # method is below
    }
    GLOBUS_AUTHORIZE_URI + '?' + globus_params.to_query
  end

  def globus_logout_uri
    GLOBUS_LOGOUT_URI
  end

  def globus_fetch_token(code, globus_action_url)
    # Query OIDC; this returns all the info we need at the same time.
    auth_header = globus_basic_auth_header # method is below
    response    = Typhoeus.post(GLOBUS_TOKEN_URI,
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
    Rails.logger.error "#{$oidc_name} token request failed: #{ex.class} #{ex.message}"
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
  # OIDC negotiations. The current Rails session_id, encoded, will do
  # the trick. The Rails session is maintained by a cookie already
  # created and maintained, at this point.
  def globus_current_state
    Digest::MD5.hexdigest( request.session_options[:id] )
  end

  # Return the registered OIDC endpoint client ID.
  # This value must be configured by the CBRAIN admin
  # in the meta data of the portal. Returns nil if unset.
  def globus_client_id
    myself = RemoteResource.current_resource
    myself.meta[:globus_client_id].presence.try(:strip)
  end

  # Return the registered OIDC endpoint client secret.
  # This value must be configured by the CBRAIN admin
  # in the meta data of the portal. Returns nil if unset.
  def globus_client_secret
    myself = RemoteResource.current_resource
    myself.meta[:globus_client_secret].presence.try(:strip)
  end

  # Returns true if the CBRAIN system is configured for
  # OIDC auth.
  def globus_auth_configured?
    myself   = RemoteResource.current_resource
    site_uri = myself.site_url_prefix.presence
    # Three conditions: site uri, client ID, client secret.
    return false if ! site_uri
    return false if ! globus_client_id
    return false if ! globus_client_secret
    true
  end

  # Record the OIDC identity for the current user.
  # (This maybe should be made into a User model method)
  def record_globus_identity(user, globus_identity)

    # In the case where a user must auth with a specific set of
    # OIDC providers, we find the first identity that
    # matches a name of that set.
    identity = set_of_identities(globus_identity).detect do |idstruct|
       user_can_link_to_globus_identity?(user, idstruct)
    end

    provider_id   = identity['identity_provider']              || identity['aud'] || cb_error("#{$oidc_name}: No identity provider")
    provider_name = identity['identity_provider_display_name'] || identity['azp'] || cb_error("#{$oidc_name}: No identity provider name")
    pref_username = identity['preferred_username'] ||
                    identity['username']                       || cb_error("#{$oidc_name}: No preferred username")

    # Special case for ORCID, because we already have fields for that provider
    # We do NOT do this in the case where the user is forced to auth with OIDC.
    if provider_name == 'ORCID' && ! user_must_link_to_globus?(user)
      orcid = pref_username.sub(/@.*/, "")
      user.meta['orcid'] = orcid
      user.addlog("Linked to ORCID identity: '#{orcid}' through #{$oidc_name}")
      return
    end

    user.meta[:globus_provider_id]        = provider_id
    user.meta[:globus_provider_name]      = provider_name # used in show page
    user.meta[:globus_preferred_username] = pref_username
    user.addlog("Linked to #{$oidc_name} identity: '#{pref_username}' on provider '#{provider_name}'")
  end

  # Removes the recorded OIDC identity for +user+
  def unlink_globus_identity(user)
    user.meta[:globus_provider_id]        = nil
    user.meta[:globus_provider_name]      = nil
    user.meta[:globus_preferred_username] = nil
    user.addlog("Unlinked #{$oidc_name} identity")
  end

  def set_of_identities(globus_identity)
    globus_identity['identity_set'] || [ globus_identity ]
  end

  def set_of_identity_provider_names(globus_identity)
    set_of_identities(globus_identity).map { |s| s['identity_provider_display_name'] }
  end

  # Returns an array of allowed identity provider names.
  # Returns nil if they are all allowed
  def allowed_globus_provider_names(user)
    user.meta[:allowed_globus_provider_names]
       .presence
      &.split(/\s*,\s*/)
      &.map(&:strip)
  end

  def user_can_link_to_globus_identity?(user, identity)
    allowed = allowed_globus_provider_names(user)
    return true if allowed.nil?
    return true if allowed.size == 1 && allowed[0] == '*'
    prov_names = set_of_identity_provider_names(identity)
    return true if (allowed & prov_names).present? # if the intersection is not empty
    false
  end

  def user_has_link_to_globus?(user)
    user.meta[:globus_provider_id].present?       &&
    user.meta[:globus_provider_name].present?     &&
    user.meta[:globus_preferred_username].present?
  end

  def user_must_link_to_globus?(user)
    user.meta[:allowed_globus_provider_names].present?
  end

  def wipe_user_password_after_globus_link(user)
    user.update_attribute(:crypted_password, "Wiped-By-#{$oidc_name}-Link-" + User.random_string)
    user.update_attribute(:salt            , "Wiped-By-#{$oidc_name}-Link-" + User.random_string)
    user.update_attribute(:password_reset  , false)
  end

  # Given a OIDC identity structure, find the user that matches it.
  # Returns the user object if found; returns a string error message otherwise.
  def find_user_with_globus_identity(globus_identity)

    provider_name = globus_identity['identity_provider_display_name']
    pref_username = globus_identity['preferred_username'] || globus_identity['username']

    id_set = set_of_identities(globus_identity) # an OIDC record can contain several identities

    # For each present identity, find all users that have it.
    # We only allow ONE cbrain user to link to any of the identities.
    users = id_set.inject([]) do |ulist, subident|
      ulist |= find_users_with_specific_identity(subident)
    end

    if users.size == 0
      Rails.logger.error "#{$oidc_name.upcase} warning: no CBRAIN accounts found for identity '#{pref_username}' on provider '#{provider_name}'"
      return "No CBRAIN user matches your #{$oidc_name} identity. Create a CBRAIN account or link your existing CBRAIN account to your #{$oidc_name} provider."
    end

    if users.size > 1
      loginnames = users.map(&:login).join(", ")
      Rails.logger.error "#{$oidc_name.upcase} error: multiple CBRAIN accounts (#{loginnames}) found for identity '#{pref_username}' on provider '#{provider_name}'"
      return "Several CBRAIN user accounts match your #{$oidc_name} identity. Please contact the CBRAIN admins."
    end

    # The one lucky user
    return users.first
  end

  # Returns an array of all users that have linked their
  # account to the +identity+ provider. The array can
  # be empty (no such users) or contain more than one
  # user (an account management error).
  def find_users_with_specific_identity(identity)
    provider_id   = identity['identity_provider']              || identity['aud'] || cb_error("#{$oidc_name}: No identity provider")
    provider_name = identity['identity_provider_display_name'] || identity['azp'] || cb_error("#{$oidc_name}: No identity provider name")
    pref_username = identity['preferred_username'] ||
                    identity['username']                       || cb_error("#{$oidc_name}: No preferred username")

    # Special case for ORCID, because we already have fields for that provider
    if provider_name == 'ORCID'
      orcid = pref_username.sub(/@.*/, "")
      users = User.find_all_by_meta_data(:orcid, orcid).to_a
      return users if users.present?
      # otherwise we fall through to detect users who linked with ORCID through OIDC
    end

    # All other globus providers
    # We need a user which match both the preferred username and provider_id
    users = User.find_all_by_meta_data(:globus_preferred_username, pref_username)
      .to_a
      .select { |user| user.meta[:globus_provider_id] == provider_id }
  end

end
