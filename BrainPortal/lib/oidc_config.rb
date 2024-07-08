
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
      end
      @oidc_config << oidc
    end

    raise errors.join("\n") if errors.any?
    return @oidc_config
  end

  def self.all
    @oidc_config
  end

  def self.enabled
    self.all.select { |oidc| oidc.enabled }
  end

  def self.enabled_names
    self.enabled.map { |oidc| oidc.name }
  end

  def self.find_by_name(name)
    @oidc_config.detect { |oidc| oidc.name == name }
  end

  def self.find_by_state(state)
    # Verifify state structure 33 + "_" + oidc_name
    # and extract name
    oidc_name = ""
    if state.length >= 34 && state[32] == '_'
      oidc_name = state[33..-1]
    end

    self.find_by_name(oidc_name)        
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

end

