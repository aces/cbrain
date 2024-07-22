
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

# This class represents an external identity provider.
# The class itself maintains a persistent frozen list of
# such providers. The providers and their attributes are
# normally loaded at boot time from the file:
#
#   RAILS_ROOT/config/oidc.yml.erb
#
# Secrets are also kept in the class, and not within the
# OidcConfig objects, so that if these objects are serialized
# by mistake, the secrets aren't revealed.
class OidcConfig

  attr_accessor :name,
                :authorize_uri, :token_uri, :logout_uri,
                :client_id, # client_secrets are kept in the class
                :scope,
                :identity_provider_key, :identity_provider_display_name_key, :identity_preferred_username_key,
                :help_label, :help_uri

  REQUIRED_KEYS = %w(
       authorize_uri token_uri logout_uri
       client_id client_secret
       scope
       identity_provider_key identity_provider_display_name_key identity_preferred_username_key
  )

  # This populate a static array of configurations in the class, as loaded
  # from a YAML.erb file. See RAILS_ROOT/config/oidc.yml.erb for an example.
  #
  # Configuration not 'enabled' will be entirely skipped.
  #
  # Any 'enabled' configuration will be validated and raise an exception
  # if it is invalid.
  def self.load_from_file(path=Rails.root + "config/oidc.yml.erb")
    @oidc_configs = [] # frozen array of OidcConfig objects
    @oidc_secrets = {} # frozen hash { oidc.name => secret }
    return [] if !File.exist?(path)

    loaded_yaml = YAML.load(ERB.new(File.read(path)).result).with_indifferent_access

    loaded_yaml.each do |name, config|

      next if ! config[:enabled] # skip entirely anything not enabled.

      errors = []
      # Check for invalid characters in name (letters case insensitive numbers and underscores only)
      errors << "Invalid OIDC name: #{name}" if name !~ /^[a-zA-Z0-9_]+$/

      # Check for missing keys
      config_keys  = config.keys.select { |k| config[k] }
      missing_keys = (REQUIRED_KEYS - config_keys)
      errors << "Missing keys #{missing_keys.join(", ")} in OIDC config: #{name}" if missing_keys.any?

      # Check if name is already used
      errors << "OIDC name #{name} is already used, entry ignored" if @oidc_configs.map(&:name).include?(name)

      raise errors.join("\n") if errors.any?

      # Make new object, store attributes
      oidc = self.new
      oidc.name                               = name
      oidc.authorize_uri                      = config[:authorize_uri]
      oidc.token_uri                          = config[:token_uri]
      oidc.logout_uri                         = config[:logout_uri]
      oidc.scope                              = config[:scope]
      oidc.client_id                          = config[:client_id]
      @oidc_secrets[name]                     = config[:client_secret]  # not kept in the object itself
      oidc.identity_provider_key              = config[:identity_provider_key]
      oidc.identity_provider_display_name_key = config[:identity_provider_display_name_key]
      oidc.identity_preferred_username_key    = config[:identity_preferred_username_key]
      oidc.help_label                         = config[:help_label]
      oidc.help_uri                           = config[:help_uri]

      # Freeze and store in class-level list
      @oidc_configs << oidc.freeze
    end

    # Freeze secrets, freeze array of configs, and return configs.
    @oidc_secrets.freeze
    @oidc_configs.freeze
    return @oidc_configs
  end

  # Returns all the enabled configurations, or an empty array of none exist.
  def self.all
    @oidc_configs || []
  end

  # Returns the names for all the configs
  def self.all_names
    self.all.map { |oidc| oidc.name }
  end

  # Find and return a config by name; returns nil if not found.
  def self.find_by_name(name)
    self.all.detect { |oidc| oidc.name == name }
  end

  # Returns a state string based on session_id and the current
  # name of the OidcConfig object; this state string helps
  # recover during the protocol negotiation the proper OidcConfig
  # we're using.
  def create_state(session_id_string)
    state = Digest::MD5.hexdigest( session_id_string ) + "_" + self.name
    return state # just to be clear
  end

  # Find and return a config by the 'state' variable used during
  # protocol negotiations. This is the reverse of create_state.
  def self.find_by_state(state)
    # Verify state structure is 33 hex chars + "_" + oidc_name
    # and extract name
    oidc_name = ""
    if state.length >= 34 && state[32] == '_'
      oidc_name = state[33..-1]
    end

    self.find_by_name(oidc_name)
  end

  # -------------------------------------------------------
  # Access methods for secrets
  # -------------------------------------------------------

  # Returns the hash of secrets stored in the class
  def self.oidc_secrets #:nodoc:
    @oidc_secrets
  end

  # Access method for the secrets; fetches from the class
  # since the OidcConfig itself doesn't store the secrets.
  def client_secret #:nodoc:
    self.class.oidc_secrets[self.name]
  end

  # -------------------------------------------------------
  # Identity structure KEY methods.
  # -------------------------------------------------------
  # These methods return the key names (as symbols)
  # that are used to extract out of a OpenID identity
  # structure these three values:
  # provider ID, provider name, and a username.

  def provider_id_key #:nodoc:
    (self.name.downcase + "_provider_id").to_sym
  end

  def provider_name_key #:nodoc:
   (self.name.downcase + "_provider_name").to_sym
  end

  def preferred_username_key #:nodoc:
    (self.name.downcase + "_preferred_username").to_sym
  end

  # Returns as a single triplet the stored values
  # provider ID, provider name and a username,
  # from an identity object.
  def identity_info(identity_struct)
    [
     identity_struct[self.identity_provider_key],
     identity_struct[self.identity_provider_display_name_key],
     identity_struct[self.identity_preferred_username_key],
    ]
  end

  # -------------------------------------------------------
  # User-side provider attribute methods
  # -------------------------------------------------------
  # These six methods get and set, on a user object, the
  # triplet of values for a provider ID, provider name,
  # and a username.

  def linked_provider_id(user) #:nodoc:
    user.meta[self.provider_id_key()]
  end

  def linked_provider_name(user) #:nodoc:
    user.meta[self.provider_name_key()]
  end

  def linked_preferred_username(user) #:nodoc:
    user.meta[self.preferred_username_key()]
  end

  def set_linked_provider_id(user, provider_id) #:nodoc:
    user.meta[self.provider_id_key()] = provider_id
  end

  def set_linked_provider_name(user, provider_name) #:nodoc:
    user.meta[self.provider_name_key()] = provider_name
  end

  def set_linked_preferred_username(user, preferred_username) #:nodoc:
    user.meta[self.preferred_username_key()] = preferred_username
  end

  # Two helpers to get and set all three values at a time;
  # in order: prov_id, prov_name and username

  def linked_oidc_info(user) #:nodoc:
    [
       linked_provider_id(user),
       linked_provider_name(user),
       linked_preferred_username(user),
    ]
  end

  def set_linked_oidc_info(user, prov_id, prov_name, username) #:nodoc:
    set_linked_provider_id(       user, prov_id  )
    set_linked_provider_name(     user, prov_name)
    set_linked_preferred_username(user, username     )
    self
  end

  def zap_linked_oidc_info(user) #:nodoc:
    set_linked_oidc_info(user, nil, nil, nil) # all three set to nil
  end

end

