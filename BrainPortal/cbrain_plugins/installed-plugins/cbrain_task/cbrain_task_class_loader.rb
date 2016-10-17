
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
# CbrainTask class loader code
#

1.times do # just starts a block so local variable don't pollute anything

  basename    = File.basename(__FILE__)
  if basename == 'cbrain_task_class_loader.rb' # usually, the symlink destination
    puts "Weird. Trying to load the loader?!?"
    break
  end

  myshorttype = Rails.root.to_s =~ /BrainPortal\z/ ? "portal" : "bourreau"
  dirname     = File.dirname(__FILE__)
  model       = basename.sub(/.rb\z/,"")
  bytype_code = "#{dirname}/#{model}/#{myshorttype}/#{model}.rb"
  common_code = "#{dirname}/#{model}/common/#{model}.rb"

  if ! CbrainTask.const_defined? model.classify
    #puts_blue "LOADING #{bytype_code}"
    require_dependency bytype_code if File.exists?(bytype_code)
    require_dependency common_code if File.exists?(common_code)
  end

end

