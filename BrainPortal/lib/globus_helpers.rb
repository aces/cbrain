
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

  def set_of_identities(globus_identity)
    globus_identity['identity_set'] || [ globus_identity ]
  end

  # Returns an array of allowed identity provider names.
  # Returns nil if they are all allowed
  def allowed_globus_provider_names(user)
    user.meta[:allowed_globus_provider_names]
       .presence
      &.split(/\s*,\s*/)
      &.map(&:strip)
  end

  def user_has_link_to_globus?(user)
    # Filter out the identities that are not allowed
    allowed        = allowed_globus_provider_names(user)
    oidc_providers = OidcConfig.enabled
    allowed_oidc   = oidc_providers.select { |oidc| allowed.include?(oidc.name) }

    # Iterate over the allowed_oidc_info
    has_link_to_oidc = false
    allowed_oidc.each do |oidc|
      next if has_link_to_oidc
      user.meta[oidc.provider_id_key].present? &&
      user.meta[oidc.provider_name_key].present? &&
      user.meta[oidc.preferred_username_key].present?
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

