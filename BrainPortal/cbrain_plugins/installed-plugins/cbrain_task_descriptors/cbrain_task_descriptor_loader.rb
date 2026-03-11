
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

#
# CbrainTask descriptor loader
#

1.times do # just starts a block so local variables don't pollute anything

  basename = File.basename(__FILE__)
  if basename == 'cbrain_task_descriptor_loader.rb' # usually, the symlink destination
    # This can happen with eager loading.
    #puts "Weird. Trying to load the loader?!?"
    break
  end

  schema     = SchemaTaskGenerator.default_schema
  descriptor = __FILE__.sub(/.rb\z/,'.json')
  next unless File.exists?(descriptor) # Bad or broken symlink? Missing json? Ignore.

  descriptor_basename = Pathname.new(descriptor).basename

  begin
    generator = SchemaTaskGenerator.generate(schema, descriptor)
  rescue StandardError => e
    generator = nil
    #puts "================="
    puts "C> Failed to generate CbrainTask from descriptor '#{descriptor_basename}'."
    puts "C> Error Message: #{e.class} #{e.message}"
    #puts e.backtrace.join("\n");
    #puts "================="
  end

  # This is a check performed while we transition from the old integrator to the new one
  new_integrated_tool = Tool.where(:cbrain_task_class_name => "BoutiquesTask::#{generator.name}").first
  if new_integrated_tool
    puts "C> Skipping integration of CbrainTask::#{generator.name} : new integration already present."
    break
  end

  begin
    generator.integrate if generator
    puts "C> [DEPRECATED] Integrated CbrainTask::#{generator.name} from descriptor '#{descriptor_basename}'"
  rescue StandardError => e
    #puts "================="
    puts "C> Failed to integrate CbrainTask from descriptor '#{descriptor_basename}'."
    puts "C> Error Message: #{e.class} #{e.message}"
    #puts e.backtrace.join("\n");
    #puts "================="
  end

end
