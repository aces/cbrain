
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

namespace :cbrain do
  namespace :minimal do
    desc "Adjusts type columns in the DB" # same as migration 20261020

    task :fix_class_names => :environment do

    types_in_db = Userfile.group(:type).pluck(:type).uniq
    #puts "D=#{types_in_db.inspect}"
    types_in_db.each do |type|      # e.g. "XMLFile"     old convention
      filebase = type.underscore    # e.g. "xml_file"
      newtype  = filebase.camelcase # e.g. "XmlFile"     new convention
      if type == newtype
        puts "No adjustments needed for #{type}"
      else
        begin
          klass = newtype.constantize
        rescue LoadError
          puts ""
          puts "Error! We want to adjust #{type} to #{newtype} but no model exists for #{newtype}."
          puts "Update the CBRAIN code base and its plugins to make sure #{filebase}.rb defines the class '#{newtype}', not '#{type}'."
          puts ""
          raise RuntimeError.new("Code base needs updating, see message above")
        end
        puts "Adjusting #{type} -> #{newtype}"
        Userfile.where("binary type = ?",type).update_all(:type => newtype)
      end
    end

    end # task cbrain:minimal:fix_class_names
  end # namespace cbrain:minimal
end # namespace cbrain
