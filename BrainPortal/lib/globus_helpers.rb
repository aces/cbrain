

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

require 'oidc_config'

# Helper for logging in using Globus identity stuff
module GlobusHelpers

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def oidc_login_uri(oidc, redirect_url)
    return nil unless oidc_auth_configured?(oidc)

    # Create the URI to authenticate with OIDC
    oidc_params = {
            :client_id     => oidc.client_id,
            :response_type => 'code',
            :scope         => oidc.scope,
            :redirect_uri  => redirect_url,  # generated from Rails routes
            :state         => oidc_current_state(oidc), # method is below
    }

    oidc.authorize_uri + '?' + oidc_params.to_query
  end

  def oidc_fetch_token(oidc, code, action_url)
    # Query OIDC; this returns all the info we need at the same time.
    auth_header = oidc_basic_auth_header(oidc) # method is below
    response    = Typhoeus.post(oidc.token_uri,
      :body   => {
                    :code           => code,
                    :redirect_uri   => action_url,
                    :grant_type     => 'authorization_code',
                  },
      :headers => { :Accept        => 'application/json',
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
    Rails.logger.error "#{oidc.name} token request failed: #{ex.class} #{ex.message}"
    return nil
  end

  # Returns the value for the Authorization header
  # when doing the client authentication.
  #
  #  "Basic 1745djfuebwifh37236djdf74.etc.etc"
  def oidc_basic_auth_header(oidc)
    "Basic " + Base64.strict_encode64("#{oidc.client_id}:#{oidc.client_secret}")
  end

  # Returns a string that should stay constants during the entire
  # OpenID negotiations. The current Rails session_id, encoded, will do
  # the trick. The Rails session is maintained by a cookie already
  # created and maintained, at this point.
  def oidc_current_state(oidc)
    Digest::MD5.hexdigest( request.session_options[:id] ) + "_" + oidc.name
  end

  # Returns true if the CBRAIN system is configured for
  # OIDC auth.
  def oidc_auth_configured?(oidc)
    myself   = RemoteResource.current_resource
    site_uri = myself.site_url_prefix.presence

    return false if ! site_uri
    return false if ! oidc.client_id
    return false if ! oidc.client_secret
    return false if ! oidc.authorize_uri
    return false if ! oidc.scope
    true
  end

  # Record the OIDC identity for the current user.
  # (This maybe should be made into a User model method)
  def record_oidc_identity(oidc, user, oidc_identity) #:nodoc:
    # In the case where a user must auth with a specific set of
    # OIDC providers, we find the first identity that
    # matches a name of that set.

    identity = set_of_identities(oidc_identity).detect do |idstruct|
        user_can_link_to_oidc_identity?(oidc, user, idstruct)
    end

    provider_id   = identity[oidc.identity_provider_key]              || cb_error("#{oidc.name}: No identity provider")
    provider_name = identity[oidc.identity_provider_display_name_key] || cb_error("#{oidc.name}: No identity provider name")
    pref_username = identity[oidc.identity_preferred_username_key]             || cb_error("#{oidc.name}: No preferred username")

    # Special case for ORCID, because we already have fields for that provider
    # We do NOT do this in the case where the user is forced to auth with OIDC.
    if provider_name == 'ORCID' && ! user_must_link_to_oidc?(user)
      orcid = pref_username.sub(/@.*/, "")
      user.meta['orcid'] = orcid
      user.addlog("Linked to ORCID identity: '#{orcid}' through #{oidc.name}")
      return
    end



    oidc.set_linked_provider_id(user, provider_id)
    oidc.set_linked_provider_name(user, provider_name)
    oidc.set_linked_preferred_username(user, pref_username)
    user.addlog("Linked to #{oidc.name} identity: '#{pref_username}' on provider '#{provider_name}'")
  end

  def set_of_identities(globus_identity)
    globus_identity['identity_set'] || [ globus_identity ]
  end

  # Returns an array of allowed identity provider names.
  # Returns nil if they are all allowed
  # Keep reference to globus for backward compability
  def allowed_oidc_provider_names(user)
    user.meta[:allowed_globus_provider_names]
      .presence
     &.split(/\s*,\s*/)
     &.map(&:strip)
  end

  def user_can_link_to_oidc_identity?(oidc, user, identity) #:nodoc:
    allowed = allowed_oidc_provider_names(user)

    return true if allowed.nil?
    return true if allowed.size == 1 && allowed[0] == '*'
    return true if allowed.include?(identity[oidc.identity_provider_display_name_key])

    false
  end

  def user_has_link_to_oidc?(user) #:nodoc:
    # Filter out the identities that are not allowed
    allowed_oidc_names = allowed_oidc_provider_names(user)
    oidc_providers     = OidcConfig.enabled

    # Iterate over the allowed_oidc_info
    oidc_providers.any? do |oidc|
      oidc.linked_provider_id(user).present? &&
      oidc.linked_provider_name(user).present? &&
      oidc.linked_preferred_username(user).present? && 
      ( allowed_oidc_names.include?('*') ||  
        allowed_oidc_names.include?(oidc.linked_provider_name(user))
      )
    end
  end

  def user_must_link_to_oidc?(user)
    user.meta[:allowed_globus_provider_names].present?
  end

  def wipe_user_password_after_oidc_link(oidc, user)
    user.update_attribute(:crypted_password, "Wiped-By-#{oidc.name}-Link-" + User.random_string)
    user.update_attribute(:salt            , "Wiped-By-#{oidc.name}-Link-" + User.random_string)
    user.update_attribute(:password_reset  , false)
  end

  def find_user_with_oidc_identity(oidc, identity)
    provider_name = identity[oidc.identity_provider_display_name]
    pref_username = identity[oidc.preferred_username]

    id_set = set_of_identities(identity) # an OIDC record can contain several identities

    # For each present identity, find all users that have it.
    # We only allow ONE cbrain user to link to any of the identities.
    users = id_set.inject([]) do |ulist, subident|
      ulist |= find_users_with_specific_identity(subident, oidc)
    end

    if users.size == 0
      Rails.logger.error "#{oidc.name} warning: no CBRAIN accounts found for identity '#{pref_username}' on provider '#{provider_name}'"
      return "No CBRAIN user matches your #{oidc.name} identity. Create a CBRAIN account or link your existing CBRAIN account to your #{oidc.name} provider."
    end

    if users.size > 1
      loginnames = users.map(&:login).join(", ")
      Rails.logger.error "#{oidc.name.upcase} error: multiple CBRAIN accounts (#{loginnames}) found for identity '#{pref_username}' on provider '#{provider_name}'"
      return "Several CBRAIN user accounts match your #{oidc.name} identity. Please contact the CBRAIN admins."
    end

    # The one lucky user
    return users.first
  end

  # Returns an array of all users that have linked their
  # account to the +identity+ provider. The array can
  # be empty (no such users) or contain more than one
  # user (an account management error).
  def find_users_with_specific_identity(identity, oidc)
    provider_id   = identity[oidc.identity_provider]              || cb_error("#{oidc.name}: No identity provider")
    provider_name = identity[oidc.identity_provider_display_name] || cb_error("#{oidc.name}: No identity provider name")
    pref_username = identity[oidc.preferred_username]             || cb_error("#{oidc.name}: No preferred username")

    # Special case for ORCID, because we already have fields for that provider
    if provider_name == 'ORCID'
      orcid = pref_username.sub(/@.*/, "")
      users = User.find_all_by_meta_data(:orcid, orcid).to_a
      return users if users.present?
      # otherwise we fall through to detect users who linked with ORCID through OIDC
    end

    # All other globus providers
    # We need a user which match both the preferred username and provider_id
    users = User.find_all_by_meta_data(oidc.preferred_username_key, pref_username)
      .to_a
      .select { |user| user.meta[oidc.provider_id_key] == provider_id }
  end

  # Removes the recorded OIDC identity for +user+
  def unlink_oidc_identity(oidc, user)
    oidc.set_linked_provider_id(user, nil)
    oidc.set_linked_provider_name(user, nil)
    oidc.set_linked_preferred_username(user, nil)    
    user.addlog("Unlinked #{oidc.name} identity")
  end


  def generate_oidc_login_uri(oidc_providers, redirect_url) #:nodoc:
    @oidc_uris = {}
    oidc_providers.each { |oidc| @oidc_uris[oidc.name] = oidc_login_uri(oidc, redirect_url)}
    return @oidc_uris
  end

end
