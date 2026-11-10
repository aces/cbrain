
#
# CBRAIN Project
#
# Copyright (C) 2008-2026
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

require 'rails_helper'
require 'open3'

# DataProvider.descendants only knows the classes Zeitwerk has already loaded.
#
# Inside the RSpec process, the answer depends on which specs ran before and on
# config.eager_load, and classes cannot be unloaded because reloading is disabled
# in the test environment. Only a new process starts from a known state, so
# this is the one spec that boots the application a second time.
RSpec.describe "Data provider types offered right after boot" do

  # Rails is booted lazily: CI= gives config.eager_load = false in the test
  # environment, otherwise eager loading would make this spec pass regardless.
  #
  # $0 is set because CbrainBootValidations refuses to boot an unknown program,
  # and that includes 'rails runner'.
  def type_choices_in_a_new_process
    script = <<~'RUBY'
      $0 = "rspec"
      require "./config/environment"
      types = Object.new.extend(DataProvidersHelper).data_provider_type_choices.flat_map(&:last)
      puts "TYPES=#{types.join(",")}"
    RUBY
    output, status = Open3.capture2e({ "CI" => nil }, RbConfig.ruby, "-e", script, :chdir => Rails.root.to_s)
    expect(status).to be_success, output
    output[/^TYPES=(.*)$/, 1].to_s.split(",")
  end

  it "includes every data provider model that has a category" do
    expected = Dir.glob(Rails.root.join("app/models/*_data_provider.rb"))
                  .map     { |file| File.basename(file, ".rb").camelize }
                  .select  { |name| name.constantize.pretty_category_name }

    expect(type_choices_in_a_new_process).to match_array(expected)
  end

end
