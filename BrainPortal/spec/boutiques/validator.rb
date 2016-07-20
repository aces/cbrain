#!/usr/bin/ruby
#
# Copyright (C) 2015
# The Royal Institution for the Advancement of Learning
# McGill University
#    and
# Centre National de la Recherche Scientifique
# CNRS
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
#
require 'json-schema'

def usage
  puts "validate: [schema_file] [json_file]"
  exit
end

if ARGV.length != 2
  usage
end

# Unpack arguments and parse descriptor
(schema_file,json_file) = ARGV
begin
  descriptor = JSON.parse( File.read(json_file) )
rescue StandardError => e
  puts "An error occurred during parsing!"
  puts e
  exit 1 # if the json itself is invalid, no need to check it
end

### Automatic descriptor validation with respect to schema structure ###
errors = JSON::Validator.fully_validate(schema_file, descriptor)

### Validation of descriptor arguments ###

## Helper functions ##
inputGet  = lambda { |s| descriptor['inputs'].map {       |v| v[s] } rescue [] }
outputGet = lambda { |s| descriptor['output-files'].map { |v| v[s] } rescue [] }
groupGet  = lambda { |s| descriptor['groups'].map {       |v| v[s] } rescue [] }
inById    = lambda { |i| descriptor['inputs'].find{       |v| v['id']==i } || {} }

## Checking command-line-keys and IDs ##

# Every command-line key appears in the command line
clkeys, cmdline = inputGet.( 'command-line-key' ), descriptor[ 'command-line' ]
clkeys.each { |k| errors.push( k + ' not in cmd line' ) unless cmdline.include?(k) }

# Command-line keys are not contained within each other
clkeys.each_with_index do |key1,i|
  for j in 0...(clkeys.length)
    errors.push( key1 + ' contains ' + clkeys[j] ) if key1.include?(clkeys[j]) && i!=j
  end
end

# IDs are unique
inIds, outIds, grpIds = inputGet.( 'id' ), outputGet.( 'id' ), groupGet.( 'id' )
allIds = inIds + outIds + grpIds
allIds.each_with_index do |s1,i|
  allIds.each_with_index do |s2,j|
    errors.push("Non-unique id " + s1) if (s1 == s2) && (i < j)
  end
end

## Checking outputs ##
descriptor['output-files'].each_with_index do |a,i|

  # Output files should have a unique path-template
  descriptor['output-files'].each_with_index do |b,j|
    next if j <= i
    if a['path-template'] == b['path-template']
      errors.push( "Output files #{a['id']} and #{b['id']} have the same path-template" )
    end
  end

end

## Checking inputs ##
descriptor["inputs"].each do |v|

  # Flag-type inputs always have command-line-flags, should not be required, and cannot be lists
  if v["type"] == "Flag"
    errors.push( "#{v["id"]} must have a command-line flag" ) unless v["command-line-flag"]
    errors.push( "#{v["id"]} cannot be a list" ) if v["list"]
    errors.push( "#{v["id"]} should not be required" ) if v["optional"]==false
  # Number constraints (mins & maxs) are sensible
  elsif v["type"] == "Number"
    min, max = v["minimum"] || -1.0/0, v["maximum"] || 1.0/0
    errors.push( "#{v['id']} cannot have greater min (#{min}) than max (#{max})" ) if min > max
  # Enum-type inputs always have specified choices (at least 1), and the default must be in the choices set
  elsif v["type"] == "Enum"
    errors.push( "#{v['id']} must have at least one value choice" ) if (v["enum-value-choices"] || []).length < 1
    badDefault = (ed = v["default-value"]).nil? ? false : !((v["enum-value-choices"] || []).include? ed)
    errors.push( "#{v['id']} cannot have an default value outside its choices" ) if badDefault
  end

  # List length constraints are sensible
  if v["list"]
    min, max = v["min-list-entries"] || 0, v["max-list-entries"] || 1.0 / 0
    errors.push( "#{v['id']} min list entries (#{min}) greater than max list entries (#{max})" ) if min > max
    errors.push( "#{v['id']} cannot have negative min list entries #{min}" ) if min < 0
    errors.push( "#{v['id']} cannot have non-positive max list entries #{max}" ) if max <= 0
  # Non-list inputs cannot have the min/max-list-entries property
  else
    ['min','max'].each{ |r| errors.push("#{v['id']} can't use #{r}-list-entries") if v["#{r}-list-entries"] }
  end

  # IDs in requires-inputs and disables-inputs are present
  for s in ['require','disable']
    (v[s + "s-inputs"] || []).each do |r|
      errors.push( s.capitalize + "d id #{r} for #{v['id']} was not found" ) unless inIds.include?(r)
    end
  end

  # An input cannot both require and disable another input
  for did in (v["requires-inputs"] || [])
    errors.push( "Id #{v['id']} requires and disables #{did}" ) if (v["disables-inputs"] || []).include?(did)
  end

  # Required inputs cannot require or disable other parameters
  if v['optional']==false
     errors.push("Required param #{v['id']} cannot require other inputs") if v['requires-inputs']
     errors.push("Required param #{v['id']} cannot disable other inputs") if v['disables-inputs']
  end

end

## Checking Groups ##
(descriptor["groups"] || []).each_with_index do |g,gi|

  # Group members must exist in the inputs, but cannot appear multiple times (in the same group or across groups)
  g['members'].each_with_index do |mcurr,i|
    (descriptor["groups"] || []).each_with_index do |g2,gj|
      g2['members'].each_with_index do |moth,j|
        unless gi > gj || (gi == gj && i >= j) # Prevent seeing the same error twice
          errors.push( "#{mcurr} cannot appear twice (in groups #{g["id"]} & #{g2["id"]})" ) if mcurr == moth
        end
      end
    end
    errors.push("Member id #{mcurr} from group #{g['id']} is not present in the inputs") unless inIds.include?(mcurr)
  end

  # Mutually exclusive groups cannot have members requiring other members, nor can they have required members
  if g["mutually-exclusive"]
    (mbrs = g["members"]).map{ |m| [m,inById.(m)] }.each do |id,m|
      errors.push( "#{id} in mutex group #{g['id']} cannot be required" ) unless m['optional'] != false
      for r in (m["requires-inputs"] || [])
        errors.push( "#{id} in mutex group #{g['id']} cannot require fellow member " + r ) if mbrs.include?( r )
      end
    end
  end

  # One-is-Required groups should also never have required members (since it is automatically satisfied)
  if g["one-is-required"]
    g["members"].map{ |m| [m,inById.(m)] }.each do |id,m|
      errors.push( "#{id} in one-is-required group #{g['id']} should not be required" ) unless m['optional'] != false
    end
  end

end

### Print the final set of errors ###
errors << "OK" if errors == []
puts "#{errors}"

