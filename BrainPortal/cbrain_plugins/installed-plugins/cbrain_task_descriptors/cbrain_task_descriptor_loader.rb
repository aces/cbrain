
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
    puts "Weird. Trying to load the loader?!?"
    break
  end

  schema     = SchemaTaskGenerator.default_schema
  descriptor = __FILE__.sub(/.rb$/,'.json')

  SchemaTaskGenerator.generate(schema, descriptor).integrate if
    File.exists?(descriptor)

end
