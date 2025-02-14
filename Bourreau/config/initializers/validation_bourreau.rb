
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

require 'socket'

CbrainSystemChecks.print_intro_info # general information printed to STDOUT

# Try extracting what it is we are booting based on the set of loaded ruby files.
first_arg      = ARGV[0]
program_name   = Regexp.last_match[1] if $PROGRAM_NAME =~ /(puma|rspec|rake)$/
program_name ||= $LOADED_FEATURES.detect do |pathname|
  break Regexp.last_match[2] if pathname =~ %r[
    (/rails/|/rails/commands/|/lib/)
    (generators|console|server|puma|rspec-rails|rake) # note that not all combinations are possible
    .rb$
    ]x
end || "unknown"
# At this point, program_name should be one of keywords in the second line of the Regex above

#
# Validations Scenarios By Program Name
#

puts "C> CBRAIN identified boot mode: #{program_name}"

# ----- CONSOLE -----
if program_name =~ /console/
  if ENV['CBRAIN_SKIP_VALIDATIONS']
    puts "C> \t- Warning: environment variable 'CBRAIN_SKIP_VALIDATIONS' is set, so we\n"
    puts "C> \t-          are skipping all validations! Proceed at your own risks!\n"
  else
    puts "C> \t- Note:  You can skip all CBRAIN validations by temporarily setting the\n"
    puts "C> \t         environment variable 'CBRAIN_SKIP_VALIDATIONS' to '1'.\n"
    CbrainSystemChecks.check(:all)
    BourreauSystemChecks.check([
      :a000_ensure_models_are_preloaded,
      :a005_ensure_boutiques_descriptors_are_loaded,
      :a050_ensure_proper_cluster_management_layer_is_loaded,
      :z000_ensure_we_have_a_forwarded_ssh_agent,
    ])
  end
  Process.setproctitle "CBRAIN Console #{RemoteResource.current_resource.class} #{RemoteResource.current_resource.name}"

# ----- SERVER -----
elsif program_name =~ /server|puma/ # normal server mode
  puts "C> \t- Running all validations for server."
  CbrainSystemChecks.check(:all)
  BourreauSystemChecks.check(:all)
  # Note, because the puma server insists on renaming its process,
  # the assignment below is also performed whenever a :show
  # action is sent to the controls controller.
  Process.setproctitle "CBRAIN Server #{RemoteResource.current_resource.class} #{RemoteResource.current_resource.name}"

# ----- RSPEC TESTS -----
elsif program_name =~ /rspec/ # test suite
  puts "C> \t- Testing with 'rspec'."
  CbrainSystemChecks.check([:a002_ensure_Rails_can_find_itself])
  BourreauSystemChecks.check([:a000_ensure_models_are_preloaded])

# ----- RAKE TASK -----
elsif program_name =~ /rake/
  puts "C> \t- Running Rake '#{first_arg}'."

# ----- RAILS GENERATE -----
elsif program_name =~ /generators/ # probably 'generate', 'destroy', 'plugin' etc, but we can't tell!
  puts "C> \t- Running Rails utility."

# ----- OTHER -----
else # any other case is something we've not yet thought about, so we crash until we fix it.
  #puts_red "PN=#{$PROGRAM_NAME} P0=$0"
  #puts_yellow $LOADED_FEATURES.sort.join("\n")
  raise "Unknown boot situation: program=#{program_name}, first arg=#{first_arg}"
end

#-----------------------------------------------------------------------------
puts "C> CBRAIN Bourreau validation completed, " + Time.now.to_s
#-----------------------------------------------------------------------------

