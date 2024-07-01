
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

end

