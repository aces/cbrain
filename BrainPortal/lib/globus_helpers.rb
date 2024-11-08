
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

# Helpers for logging in using OpenID identity stuff
# Originally, this file only implemented Globus support,
# but refactoring in July 2024 added support for
# more generic OpenID providers. The module kept its name.
module GlobusHelpers

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  # Create a URL for a login button, with the redirect URL
  # to call back to.
  def oidc_login_uri(oidc, redirect_url)
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

    # Globus hack: the identity struct we need is the first entry in the "identity_set", if
    # it exists.
    identity_struct = identity_struct['identity_set'][0] if identity_struct['identity_set'].present?

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
    # Some dubious clients post to /sessions with no prior cookies set, so rails end up
    # with no ID for the session in the request. We generate a dummy one that will make auth fail.
    rails_session_id = request.session_options[:id] || (rand(10000000000).to_s + rand(22222222222).to_s)
    oidc.create_state( rails_session_id )
  end

  # Record the OIDC identity for the current user.
  # (This maybe should be made into a User model method)
  def record_oidc_identity(oidc, user, identity) #:nodoc:

    provider_id, provider_name, pref_username = oidc.identity_info(identity)

    # Special case for ORCID, because we already have fields for that provider
    # We do NOT do this in the case where the user is forced to auth with OIDC.
    if provider_name == 'ORCID' && ! user_must_link_to_oidc?(user)
      orcid = pref_username.sub(/@.*/, "")
      user.meta['orcid'] = orcid
      user.addlog("Linked to ORCID identity: '#{orcid}' through #{oidc.name}")
      return
    end

    # Record the three values in the user's account
    oidc.set_linked_oidc_info(user, provider_id, provider_name, pref_username)
    user.addlog("Linked to #{oidc.name} identity: '#{pref_username}' on provider '#{provider_name}'")
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
    allowed_oidc_names = allowed_oidc_provider_names(user)

    # Iterate over the allowed_oidc_info
    OidcConfig.all.any? do |oidc|
      prov_id, prov_name, prov_user = oidc.linked_oidc_info(user)
      prov_id.present? && prov_name.present? && prov_user.present? &&
      ( allowed_oidc_names.nil?          ||
        allowed_oidc_names.include?('*') ||
        allowed_oidc_names.include?(prov_name)
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

  # Verify that only one user has a link to the identity. Returns
  # the user, or logs the problem and returns a string error message.
  def find_user_with_oidc_identity(oidc, identity)

    _, provider_name, pref_username = oidc.identity_info(identity)

    # We only allow ONE cbrain user to link to the identity.
    users = find_all_users_with_specific_identity(oidc, identity)

    if users.size == 0
      Rails.logger.error "#{oidc.name} warning: no CBRAIN accounts found for identity '#{pref_username}' on provider '#{provider_name}'"
      return "No CBRAIN user matches your #{oidc.name} identity. Create a CBRAIN account or link your existing CBRAIN account to your #{oidc.name} provider."
    end

    if users.size > 1
      loginnames = users.map(&:login).join(", ")
      Rails.logger.error "#{oidc.name.upcase} error: multiple CBRAIN accounts (#{loginnames}) found for identity '#{pref_username}' on provider '#{provider_name}'"
      return "Several CBRAIN user accounts match your #{oidc.name} identity. Please contact the CBRAIN admins, as this should never happen."
    end

    # The one lucky user
    return users.first
  end

  # Returns an array of all users that have linked their
  # account to the +identity+ provider. The array can
  # be empty (no such users) or contain more than one
  # user (an account management error).
  def find_all_users_with_specific_identity(oidc, identity)
    provider_id, provider_name, pref_username = oidc.identity_info(identity)

    # Special case for ORCID, because we already have fields for that provider
    if provider_name == 'ORCID'
      orcid = pref_username.sub(/@.*/, "")
      users = User.find_all_by_meta_data(:orcid, orcid).to_a
      return users if users.present?
      # otherwise we fall through to detect users who linked with ORCID through OIDC
    end

    # All other globus providers
    # We need a user which match both the preferred username and provider_id
    #
    # Implementation note.
    # This code assumes/knows that OidcConfig stores the linked info into
    # the metadata store; if this changes in the future the OidcConfig should
    # really become the finder for the users.
    users = User.find_all_by_meta_data(oidc.preferred_username_key, pref_username)
      .to_a
      .select { |user| oidc.linked_provider_id(user) == provider_id }
  end

  # Removes the recorded OIDC identity for +user+
  def unlink_oidc_identity(oidc, user)
    oidc.zap_linked_oidc_info(user) # prov_id, prov_name, username set to NIL
    user.addlog("Unlinked #{oidc.name} identity")
  end

  # Returns a hash table with keys being the names of the OidcConfigs
  # and values being the login URL that includes the redirect callback URL.
  # This is used by the interface to generate login buttons.
  def generate_oidc_login_uri(oidc_providers, redirect_url)
    oidc_providers.map do |oidc|
      [ oidc.name, oidc_login_uri(oidc, redirect_url) ]
    end.to_h
  end

end
