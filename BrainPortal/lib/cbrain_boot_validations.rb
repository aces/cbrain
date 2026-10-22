
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
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

#=================================================================
# IMPORTANT NOTE : When adding new validation code in this file,
# remember that in deployment there can be several instances of
# the Rails application all executing this code at the same time.
#=================================================================

# This class is just a container for a bunch of code
# executed once at the end of all the boot process for
# the CBRAIN application.
class CbrainBootValidations

  cattr_accessor :cbrain_app

  def self.is_portal?
    self.cbrain_app == :portal
  end

  def self.is_bourreau?
    self.cbrain_app == :bourreau
  end

  def self.detect_mode
    if    Rails.app_class.to_s == "CbrainRailsPortal::Application"
      self.cbrain_app = :portal
    elsif Rails.app_class.to_s == "CbrainRailsBourreau::Application"
      self.cbrain_app = :bourreau
    else
      raise "Configuration error: can't figure out what CBRAIN application we are."
    end
  end

  def self.validate!

    self.detect_mode

    CbrainSystemChecks.print_intro_info # general information printed to STDOUT

    # Try extracting what it is we are booting based on the set of loaded ruby files.
    program_name = Regexp.last_match[1] if $PROGRAM_NAME =~ /(puma|rspec|rake)$/

    if ! program_name
      program_names = caller.to_a.map do |callerline|
        # from .../lib/rails/commands/console/console_command.rb:86:in blah
        next unless callerline.to_s.match( %r[ rails/commands/([a-z]+) ]x )
        Regexp.last_match[1]
      end.compact.uniq
      program_name = 'console' if program_names[0] == 'console'
      program_name = 'server'  if program_names[0] == 'server'
      program_name = 'utils'   if program_names[0] == 'generate'
      program_name = 'rake'    if program_names[0] == 'rake'
      puts "Unknown program names: #{program_names.inspect}" if program_name.nil? && program_names.present?
    end

    program_name ||= 'unknown'
    program_name = "server" if program_name == "puma"

    # At this point, program_name should be one of keywords extracted from the Regex above
    puts "V> CBRAIN identified boot mode: #{program_name}"

    self.validations_for_console  if program_name == 'console'
    self.validations_for_server   if program_name == 'server'
    self.validations_for_rake     if program_name == 'rake'
    self.validations_for_rspec    if program_name == 'rspec'
    self.validations_for_utils    if program_name == 'utils'
    self.validations_for_unknown! if program_name == 'unknown' # this will crash on purpose

    #-----------------------------------------------------------------------------
    puts "V> CBRAIN BrainPortal validation completed, " + Time.now.to_s
    #-----------------------------------------------------------------------------

  end


  #
  # Validations Scenarios By Program Name
  #

  # ----- CONSOLE -----

  def self.validations_for_console
    if ENV['CBRAIN_SKIP_VALIDATIONS']
      puts "V> \t- Warning: environment variable 'CBRAIN_SKIP_VALIDATIONS' is set, so we\n"
      puts "V> \t-          are skipping all validations! Proceed at your own risks!\n"
      if is_portal?
        CbrainSystemChecks.check([:a002_ensure_Rails_can_find_itself]) rescue nil
      end
    else
      puts "V> \t- Note:  You can skip all CBRAIN validations by temporarily setting the\n"
      puts "V> \t         environment variable 'CBRAIN_SKIP_VALIDATIONS' to '1'.\n"
      CbrainSystemChecks.check(:all)
      PortalSystemChecks.check(:all, :except => [ :z020_start_background_activity_workers ]) if is_portal?
      BourreauSystemChecks.check([
       :a000_ensure_models_are_preloaded,
       :a005_ensure_boutiques_descriptors_are_loaded,
       :a050_ensure_proper_cluster_management_layer_is_loaded,
       :z000_ensure_we_have_a_forwarded_ssh_agent,
      ]) if is_bourreau?
    end
    Process.setproctitle "CBRAIN Console #{RemoteResource.current_resource.class} #{RemoteResource.current_resource.name}"
  end

  # ----- SERVER -----

  def self.validations_for_server
    puts "V> \t- Running all validations for server."
    CbrainSystemChecks.check(:all)
    PortalSystemChecks.check(:all)   if is_portal?
    BourreauSystemChecks.check(:all) if is_bourreau?
    # Note, because the puma server insists on renaming its process,
    # the assignment below is also performed whenever a show
    # action is sent to the controls controller.
    Process.setproctitle "CBRAIN Server #{RemoteResource.current_resource.class} #{RemoteResource.current_resource.name}"
  end

  # ----- RSPEC TESTS -----

  def self.validations_for_rspec
    puts "V> \t- Testing with 'rspec'."
    CbrainSystemChecks.check([:a002_ensure_Rails_can_find_itself])
    if is_portal?
      PortalSystemChecks.check([:a000_ensure_models_are_preloaded])
      PortalSystemChecks.check([:a010_check_if_pending_database_migrations])
    else
      BourreauSystemChecks.check([:a000_ensure_models_are_preloaded])
    end
  end

  # ----- RAKE TASK -----

  def self.validations_for_rake
    return if is_bourreau?
    #
    # Rake Exceptions By First Argument
    #
    skip_validations_for = [ /^db:/, /^cbrain:plugins/, /^cbrain:test/, /^route/, /^assets/, /^cbrain:nagios/, /^cbrain:boutiques:rewrite/ ]
    first_arg = ARGV.detect { |x| x =~ /^[\w:]+/i } # first thing that looks like abc:def:ghi
    if first_arg.blank?
      puts "Warning: please run rake tasks with 'rake', not 'rails'."
    end
    if skip_validations_for.any? { |p| first_arg =~ p }
      #------------------------------------------------------------------------------
      puts "V> \t- No validations needed for rake task '#{first_arg}'. Skipping."
      #------------------------------------------------------------------------------
      CbrainSystemChecks.check([:a002_ensure_Rails_can_find_itself]) if first_arg == "db:seed:test:api"
      PortalSystemChecks.check([:a000_ensure_models_are_preloaded])  if first_arg == "db:seed:test:api"
    else # all other rake cases
      #------------------------------------------------------------------------------
      puts "V> \t- All validations will run for rake task '#{first_arg}'."
      #------------------------------------------------------------------------------
      CbrainSystemChecks.check(:all)
      PortalSystemChecks.check(:all, :except => [ :z020_start_background_activity_workers ])
    end
  end

  # ----- RAILS GENERATE ETC -----

  def self.validations_for_utils
    puts "V> \t- Running Rails utility."
  end

  # ----- OTHER : STOP -----

  # Any other case is something we've not yet thought about, so we crash until we fix it.
  def self.validations_for_unknown!
    #puts_red "PN=#{$PROGRAM_NAME} P0=$0"
    #puts_yellow $LOADED_FEATURES.sort.join("\n")
    raise "Unknown boot situation: program=#{program_name}, ARGV=#{ARGV.inspect}"
  end

end # class
