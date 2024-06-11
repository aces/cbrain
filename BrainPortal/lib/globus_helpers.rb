
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

  # Returns the URI to send users to the OIDC authentication page.
  # The parameter globus_action_url should be the URL to the controller
  # action here in CBRAIN that will received the POST response.
  def globus_login_uri(oidc_name, oidc_provider)
    return nil unless globus_auth_configured?(oidc_provider)

    client_id = oidc_provider[:client_id]
    scope     = oidc_provider[:scope]

    # Create the URI to authenticate with OIDC
    globus_params = {
      :client_id     => client_id,
      :response_type => 'code',
      :scope         => scope,
      :redirect_uri  => "http://localhost:3002/globus",  # generated from Rails routes
      :state         => globus_current_state(oidc_name), # method is below
    }

    oidc_provider[:authorize_uri] + '?' + globus_params.to_query
  end

  def globus_fetch_token(code, globus_action_url,token_uri, oidc_name)
    # Query OIDC; this returns all the info we need at the same time.
    auth_header = globus_basic_auth_header # method is below
    response    = Typhoeus.post(token_uri,
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
    Rails.logger.error "#{oidc_name} token request failed: #{ex.class} #{ex.message}"
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
  def globus_current_state(oidc_name)
    md5 = Digest::MD5.hexdigest( RemoteResource.current_resource.name )
    !oidc_name ? md5  :
                 md5 + "_" + oidc_name
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
  def globus_auth_configured?(oidc_provider=nil)
    myself   = RemoteResource.current_resource
    site_uri = myself.site_url_prefix.presence
    # Four conditions: client_id, client_secret, authorize_uri, scope
    return false if ! oidc_provider[:client_id]
    return false if ! oidc_provider[:client_secret]
    return false if ! oidc_provider[:authorize_uri]
    return false if ! oidc_provider[:scope]
    true
  end

  # Record the OIDC identity for the current user.
  # (This maybe should be made into a User model method)
  def record_globus_identity(user, globus_identity, oidc_name, oidc_config)
    # In the case where a user must auth with a specific set of
    # OIDC providers, we find the first identity that
    # matches a name of that set.
    identity = set_of_identities(globus_identity).detect do |idstruct|
       user_can_link_to_globus_identity?(user, oidc_config, idstruct)
    end

    provider_id   = identity[oidc_config[:identity_provider]]              || cb_error("#{oidc_name}: No identity provider")
    provider_name = identity[oidc_config[:identity_provider_display_name]] || cb_error("#{oidc_name}: No identity provider name")
    pref_username = identity[oidc_config[:preferred_username]]             || cb_error("#{oidc_name}: No preferred username")

    # Special case for ORCID, because we already have fields for that provider
    # We do NOT do this in the case where the user is forced to auth with OIDC.
    if provider_name == 'ORCID' && ! user_must_link_to_globus?(user)
      orcid = pref_username.sub(/@.*/, "")
      user.meta['orcid'] = orcid
      user.addlog("Linked to ORCID identity: '#{orcid}' through #{oidc_name}")
      return
    end

    user.meta[oidc_provider_id_key(oidc_name)]        = provider_id
    user.meta[oidc_provider_name_key(oidc_name)]      = provider_name
    user.meta[oidc_preferred_username_key(oidc_name)] = pref_username
    user.addlog("Linked to #{oidc_name} identity: '#{pref_username}' on provider '#{provider_name}'")
  end

  # Removes the recorded OIDC identity for +user+
  def unlink_globus_identity(user, oidc_name)
    oidc_provider_id_key(oidc_name)

    user.meta[oidc_provider_id_key(oidc_name)]        = nil
    user.meta[oidc_provider_name_key(oidc_name)]      = nil
    user.meta[oidc_preferred_username_key(oidc_name)] = nil
    user.addlog("Unlinked #{oidc_name} identity")
  end

  def set_of_identities(globus_identity)
    globus_identity['identity_set'] || [ globus_identity ]
  end

  def set_of_identity_provider_names(oidc_config, globus_identity)
    identity_provider_display_name_key = oidc_config[:identity_provider_display_name]
    set_of_identities(globus_identity).map { |s| s[identity_provider_display_name_key] }
  end

  # Returns an array of allowed identity provider names.
  # Returns nil if they are all allowed
  def allowed_globus_provider_names(user)
    user.meta[:allowed_globus_provider_names]
       .presence
      &.split(/\s*,\s*/)
      &.map(&:strip)
  end

  def user_can_link_to_globus_identity?(user, oidc_config, identity)
    allowed = allowed_globus_provider_names(user)
    return true if allowed.nil?
    return true if allowed.size == 1 && allowed[0] == '*'
    prov_names = set_of_identity_provider_names(oidc_config, identity)
    return true if (allowed & prov_names).present? # if the intersection is not empty
    false
  end

  def user_has_link_to_globus?(user,oidc_info)
    allowed = allowed_globus_provider_names(user)

    # Filter out the identities that are not allowed
    allowed_oidc_info = oidc_info.select { |oidc_client, oidc_config| allowed.include?(oidc_client) }

    # Iterate over the allowed_oidc_info
    has_link_to_oidc = false
    allowed_oidc_info.each do |oidc_name, oidc_config|
      next if has_link_to_oidc
      user.meta[oidc_provider_id_key(oidc_name)].present? &&
      user.meta[oidc_provider_name_key(oidc_name)].present? &&
      user.meta[oidc_preferred_username_key(oidc_name)].present?
      has_link_to_oidc = true
    end
    has_link_to_oidc
  end

  def user_must_link_to_globus?(user)
    user.meta[:allowed_globus_provider_names].present?
  end

  def wipe_user_password_after_globus_link(user, oidc_name)
    user.update_attribute(:crypted_password, "Wiped-By-#{oidc_name}-Link-" + User.random_string)
    user.update_attribute(:salt            , "Wiped-By-#{oidc_name}-Link-" + User.random_string)
    user.update_attribute(:password_reset  , false)
  end

  # Given a OIDC identity structure, find the user that matches it.
  # Returns the user object if found; returns a string error message otherwise.
  def find_user_with_globus_identity(oidc_identity, oidc_name, oidc_config)

    provider_name = oidc_identity[oidc_config[:identity_provider_display_name]]
    pref_username = oidc_identity[oidc_config[:preferred_username]]

    id_set = set_of_identities(oidc_identity) # an OIDC record can contain several identities

    # For each present identity, find all users that have it.
    # We only allow ONE cbrain user to link to any of the identities.
    users = id_set.inject([]) do |ulist, subident|
      ulist |= find_users_with_specific_identity(subident, oidc_config, oidc_name)
    end

    if users.size == 0
      Rails.logger.error "#{oidc_name} warning: no CBRAIN accounts found for identity '#{pref_username}' on provider '#{provider_name}'"
      return "No CBRAIN user matches your #{oidc_name} identity. Create a CBRAIN account or link your existing CBRAIN account to your #{oidc_name} provider."
    end

    if users.size > 1
      loginnames = users.map(&:login).join(", ")
      Rails.logger.error "#{oidc_name.upcase} error: multiple CBRAIN accounts (#{loginnames}) found for identity '#{pref_username}' on provider '#{provider_name}'"
      return "Several CBRAIN user accounts match your #{oidc_name} identity. Please contact the CBRAIN admins."
    end

    # The one lucky user
    return users.first
  end

  # Returns an array of all users that have linked their
  # account to the +identity+ provider. The array can
  # be empty (no such users) or contain more than one
  # user (an account management error).
  def find_users_with_specific_identity(identity, oidc_config, oidc_name)
    provider_id   = identity[oidc_config[:identity_provider]]              || cb_error("#{oidc_name}: No identity provider")
    provider_name = identity[oidc_config[:identity_provider_display_name]] || cb_error("#{oidc_name}: No identity provider name")
    pref_username = identity[oidc_config[:preferred_username]]             || cb_error("#{oidc_name}: No preferred username")
  
    # Special case for ORCID, because we already have fields for that provider
    if provider_name == 'ORCID'
      orcid = pref_username.sub(/@.*/, "")
      users = User.find_all_by_meta_data(:orcid, orcid).to_a
      return users if users.present?
      # otherwise we fall through to detect users who linked with ORCID through OIDC
    end

    # All other globus providers
    # We need a user which match both the preferred username and provider_id
    users = User.find_all_by_meta_data(oidc_preferred_username_key(oidc_name), pref_username)
      .to_a
      .select { |user| user.meta[oidc_provider_id_key(oidc_name)] == provider_id }
  end

  private

  def oidc_provider_id_key(oidc_name)
    "#{oidc_name.downcase}_provider_id".to_sym
  end

  def oidc_provider_name_key(oidc_name)
    "#{oidc_name.downcase}_provider_name".to_sym
  end

  def oidc_preferred_username_key(oidc_name)
    "#{oidc_name.downcase}_preferred_username".to_sym
  end


end

