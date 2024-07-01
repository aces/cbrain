
#
# CBRAIN Project
#
# Copyright (C) 2008-2024
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

class OidcConfig

    attr_reader :name, :authorize_uri, :token_uri, :logout_uri, :scope, :client_secret, :client_id,
                :identity_provider, :identity_provider_display_name, :preferred_username,
                :enabled, :login_button_label, :link_button_label, :link_to, :link_to_uri,
                :cb_login_uri, :nh_login_uri

    def self.load_from_file(path=Rails.root + "config/oidc.yml")
        @oidc_config = []
 
        loaded_yaml = YAML.load(ERB.new(File.read(path)).result).with_indifferent_access

        needed_keys = %w[authorize_uri token_uri logout_uri scope client_secret client_id
                         identity_provider identity_provider_display_name preferred_username
                         enabled login_button_label link_button_label link_to]

        errors = []
        loaded_yaml.each do |name, config|

            # Check for invalid characters in name (letters case insensitive numbers and underscores only)
            errors << "Invalid OIDC name: #{name}" if name !~ /^[a-zA-Z0-9_]+$/
            # Check for missing keys
            errors << "Missing keys #{(needed_keys - config.keys).join(", ")} in OIDC config: #{name}" if (needed_keys - config.keys).any?
            # Check if name is already used
            errors << "OIDC name #{name} is already used (ignore entry)" if @oidc_config.map(&:name).include?(name)

            oidc = self.new
            oidc.instance_eval do
                @name                           = name
                @authorize_uri                  = config[:authorize_uri]
                @token_uri                      = config[:token_uri]
                @logout_uri                     = config[:logout_uri]
                @scope                          = config[:scope]
                @client_secret                  = config[:client_secret]
                @client_id                      = config[:client_id]
                @identity_provider              = config[:identity_provider]
                @identity_provider_display_name = config[:identity_provider_display_name]
                @preferred_username             = config[:preferred_username]
                @enabled                        = config[:enabled]
                @login_button_label             = config[:login_button_label]
                @link_button_label              = config[:link_button_label]
                @link_to                        = config[:link_to]
                @cb_login_uri                   = oidc_login_uri(RemoteResource.current_resource.site_url_prefix + "/globus")
                @nh_login_uri                   = oidc_login_uri(RemoteResource.current_resource.site_url_prefix + "/nh_globus")
            end
            @oidc_config << oidc
        end

        raise errors.join("\n") if errors.any?
        return @oidc_config
    end

    def self.find_by_name(name)
        @oidc_config.detect { |oidc| oidc.name == name }
    end

    def self.all
        @oidc_config
    end

    def self.enabled
        @oidc_config.select { |oidc| oidc.enabled }
    end

    def self.enabled_names
        self.enabled.map { |oidc| oidc.name }
    end

    def set_user_prefered_name(user, oidc_identity)
        key = generate_meta_key(self.name, "preferred_username")
        user.meta[key] = oidc_identity[self.preferred_username]
    end

    def get_user_prefered_name(user)
        key = generate_meta_key(self.name, "preferred_username")
        user.meta[key]
    end

    def generate_meta_key(oidc_name, key)
        "#{oidc_name}_#{key}".to_sym
    end


    def oidc_login_uri(redirect_url)
        return nil unless oidc_auth_configured?

        # Create the URI to authenticate with OIDC
        oidc_params = {
            :client_id     => self.client_id,
            :response_type => 'code',
            :scope         => self.scope,
            :redirect_uri  => redirect_url,  # generated from Rails routes
            :state         => current_state, # method is below
        }

        self.authorize_uri + '?' + oidc_params.to_query
    end

    # Returns true if the CBRAIN system is configured for
    # OIDC auth.
    def oidc_auth_configured?
        myself   = RemoteResource.current_resource
        site_uri = myself.site_url_prefix.presence

        return false if ! site_uri
        return false if ! self.client_id
        return false if ! self.client_secret
        return false if ! self.authorize_uri
        return false if ! self.scope
        true
    end

    def current_state
        Digest::MD5.hexdigest( self.name ) + "_" + self.name
    end

    def fetch_token(code, action_url)
        # Query OIDC; this returns all the info we need at the same time.
        auth_header = basic_auth_header # method is below
        response    = Typhoeus.post(self.token_uri,
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
        Rails.logger.error "#{self.name} token request failed: #{ex.class} #{ex.message}"
        return nil
    end

  # Returns the value for the Authorization header
  # when doing the client authentication.
  #
  #  "Basic 1745djfuebwifh37236djdf74.etc.etc"
  def basic_auth_header
    "Basic " + Base64.strict_encode64("#{self.client_id}:#{self.client_secret}")
  end

  # Record the OIDC identity for the current user.
  # (This maybe should be made into a User model method)
  def record_identity(user, oidc_identity) #:nodoc:
    # In the case where a user must auth with a specific set of
    # OIDC providers, we find the first identity that
    # matches a name of that set.
 
    identity = set_of_identities(oidc_identity).detect do |idstruct|
        self.user_can_link_to_identity?(user, idstruct)
    end
 
    provider_id   = identity[self.identity_provider]              || cb_error("#{self.name}: No identity provider")
    provider_name = identity[self.identity_provider_display_name] || cb_error("#{self.name}: No identity provider name")
    pref_username = identity[self.preferred_username]             || cb_error("#{self.name}: No preferred username")
 
    # Special case for ORCID, because we already have fields for that provider
    # We do NOT do this in the case where the user is forced to auth with OIDC.
    if provider_name == 'ORCID' && ! user_must_link_to_globus?(user)
      orcid = pref_username.sub(/@.*/, "")
      user.meta['orcid'] = orcid
      user.addlog("Linked to ORCID identity: '#{orcid}' through #{oidc_name}")
      return
    end
 
    user.meta[self.provider_id_key]        = provider_id
    user.meta[self.provider_name_key]      = provider_name
    user.meta[self.preferred_username_key] = pref_username
    user.addlog("Linked to #{self.name} identity: '#{pref_username}' on provider '#{provider_name}'")
  end

  def user_must_link_to_oidc?(user)
    user.meta[:allowed_oidc_provider_names].present?
  end

  def user_can_link_to_identity?(user, identity) #:nodoc:
    allowed = allowed_oidc_provider_names(user)
  
    return true if allowed.nil?
    return true if allowed.size == 1 && allowed[0] == '*'
    return true if allowed.include?(self.identity_provider_display_name)

    false
  end

  # Returns an array of allowed identity provider names.
  # Returns nil if they are all allowed
  def allowed_oidc_provider_names(user)
    user.meta[:allowed_oidc_provider_names]
    .presence
   &.split(/\s*,\s*/)
   &.map(&:strip)
  end

  def set_of_identity_provider_names(oidc_identity) #:nodoc:
    set_of_identities(oidc_identity).map { |s| self.identity_provider_display_name }
  end

  def set_of_identities(oidc_identity) #:nodoc:
    oidc_identity['identity_set'] || [ oidc_identity ]
  end

  # Given a OIDC identity structure, find the user that matches it.
  # Returns the user object if found; returns a string error message otherwise.
  def find_user_with_oidc_identity(identity)
    provider_name = identity[self.identity_provider_display_name]
    pref_username = identity[self.preferred_username]

    id_set = set_of_identities(identity) # an OIDC record can contain several identities

    # For each present identity, find all users that have it.
    # We only allow ONE cbrain user to link to any of the identities.
    users = id_set.inject([]) do |ulist, subident|
      ulist |= find_users_with_specific_identity(subident)
    end

    if users.size == 0
      Rails.logger.error "#{self.name} warning: no CBRAIN accounts found for identity '#{pref_username}' on provider '#{provider_name}'"
      return "No CBRAIN user matches your #{self.name} identity. Create a CBRAIN account or link your existing CBRAIN account to your #{self.name} provider."
    end

    if users.size > 1
      loginnames = users.map(&:login).join(", ")
      Rails.logger.error "#{self.name.upcase} error: multiple CBRAIN accounts (#{loginnames}) found for identity '#{pref_username}' on provider '#{provider_name}'"
      return "Several CBRAIN user accounts match your #{self.name} identity. Please contact the CBRAIN admins."
    end

    # The one lucky user
    return users.first
  end

  # Returns an array of all users that have linked their
  # account to the +identity+ provider. The array can
  # be empty (no such users) or contain more than one
  # user (an account management error).
  def find_users_with_specific_identity(identity)
    provider_id   = identity[self.identity_provider]              || cb_error("#{self.name}: No identity provider")
    provider_name = identity[self.identity_provider_display_name] || cb_error("#{self.name}: No identity provider name")
    pref_username = identity[self.preferred_username]             || cb_error("#{self.name}: No preferred username")
  
    # Special case for ORCID, because we already have fields for that provider
    if provider_name == 'ORCID'
      orcid = pref_username.sub(/@.*/, "")
      users = User.find_all_by_meta_data(:orcid, orcid).to_a
      return users if users.present?
      # otherwise we fall through to detect users who linked with ORCID through OIDC
    end

    # All other globus providers
    # We need a user which match both the preferred username and provider_id
    users = User.find_all_by_meta_data(self.preferred_username_key, pref_username)
      .to_a
      .select { |user| user.meta[self.provider_id_key] == provider_id }
  end

  def provider_id_key #:nodoc:
    (self.name.downcase + "_provider_id").to_sym
  end

  def provider_name_key #:nodoc:
   (self.name.downcase + "_provider_name").to_sym
  end
  
  def preferred_username_key #:nodoc:
    (self.name.downcase + "_preferred_username").to_sym
  end

  def user_can_link_to_oidc_identity?(user, oidc, oidc_identity) #:nodoc:
    allowed         = allowed_oidc_provider_names(user)
    return true if allowed.nil?
    return true if allowed.size == 1 && allowed[0] == '*'

    oidc_providers  = OidcConfig.enabled
    allowed_clients = allowed.map { |name| oidc_providers[name][:client_id] }

    prov_names = set_of_identity_provider_names(oidc_config, identity)
    return true if (allowed_clients & prov_names).present? # if the intersection is not empty
    false
  end


  # Removes the recorded OIDC identity for +user+
  def unlink_identity(user)
    user.meta[self.provider_id_key]        = nil
    user.meta[self.provider_name_key]      = nil
    user.meta[self.preferred_username_key] = nil
    user.addlog("Unlinked #{self.name} identity")
  end 
end
