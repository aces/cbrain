#!/usr/bin/env ruby

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

# This is the mock application used to test the Boutiques framework in cbrain.
# It tries to cover as many Boutiques features as possible.
# In essence, it takes a command line string as input and merely checks that the
# implied input parameters match the specifications (as in the json descriptor).
# The exit code of the script is used to test correctness in the unit tests of Boutiques.

require 'optparse'
require 'fileutils'
require_relative 'test_helpers'
include TestHelpers

# Colours for more readable verbose text
class String
  def colour(code) "\e[#{code}m#{self}\e[0m" end
  def red() colour(31) end
  def green() colour(32) end
  def blue() colour(34) end
end

# Print raw input string
print("\nRunning Boutiques simple test app\nRaw Input=#{ARGV.to_s}".blue) if ARGV.include? "--verbose"

# Dictionary of inputs and verbosity to be filled
options, verbose = {}, false

# Helper for exiting and printing error message (puts does not print arrays well)
leave = lambda { |msg,code| print ( "\n" + msg.to_s + " [#{code}]" + "\n").red if verbose; exit code }

# The Ruby argument parser cannot nicely handle space-separated lists, so it is done now
HandleSpaceSeparatedLists.( ARGV, options )

# Check special flag separation argument (should be '=')
# Must check before read-in, since parser cannot differentiate "-x =p" & "-x=p"
unless (xind = ARGV.each_index.select { |i| ARGV[i].start_with?('-x') }[0] ).nil?
  unless ARGV[xind][2] == "="
    leave.("ERROR: argument to -x was not '='-separated", 5)
  else
    ARGV << "-x" << ARGV[xind][3..-1]
    ARGV.delete_at(xind)
  end
end

# Use the built-in Ruby option parser to handle regular arguments
# Does not test all possible combinations; could potentially use erb for this if desired
op = GenerateOptionParser.(options)

# Perform the parsing
# Handle errors in the command line structure itself
# Errors here usually destroy the proper assignment of the other arguments, so such errors are fast-fail
begin
  op.parse!(ARGV)
rescue
  leave.( "ERROR: " + $!.to_s , 1)
end

# Ensure that all the arguments were parsed
leave.("ERROR: leftover arguments " + ARGV.to_s, 1) if ARGV != []

# Set verbosity
verbose = true if options.delete(:verbose)

# Check input types
# The automatic parser already does this to an extent, but since it is incomplete and
# we also rely on some manual parsing, we have to check it again
AllParams = Strings + Flags + Files + Numbers + NumLists + FileLists + StringLists
options.each do |key, value|
  if Strings.include?(key)      && ! (String===value)
    print("\n Handling String type error: #{key.to_s}, #{Strings.include? key}, #{value.class} \n")
    leave.( "ERROR: input (-#{key.to_s}, #{value}) is not a string", 3)
  elsif Flags.include?(key)     && ! (value==true || value==false)
    leave.( "ERROR: input (-#{key.to_s}, #{value}) is not a boolean", 3)
  elsif Files.include?(key)     && !( String===value && File.exist?(value) )
    leave.( "ERROR: input (-#{key.to_s}, #{value}) is not an existent filename", 10)
  elsif Numbers.include?(key)   && ( Float(value) rescue nil )==nil
    leave.( "ERROR: input (-#{key.to_s}, #{value}) is not a number", 3)
  elsif (NumLists + FileLists + StringLists).include?(key) && ! (Array===value)
    leave.( "ERROR: input (-#{key.to_s}, #{value}) is not an array", 3)
  elsif FileLists.include?(key) && value.any?{ |v| ! File.exist?(v) }
    leave.( "ERROR: input (-#{key.to_s}, #{value}) contains a non-existent filename", 10)
  elsif ! AllParams.include?(key)
    leave.( "ERROR: input (-#{key.to_s}, #{value}) is not recognized", 3)
  end
end

# Transform number lists and check types
NumLists.each do |key|
  value = options[key]
  unless value.nil?
    curr = value.map { |n| Float(n) rescue nil }
    msg = "ERROR: input list (-#{key.to_s}, #{value}) contained non-numeric elements"
    leave.(msg, 4) if curr.include? nil
  end
end

# Check disables/requires
unless options[:i].nil? # i -d-> j,k
  leave.("ERROR: -i disables -j", 6) unless options[:j].nil?
  leave.("ERROR: -i disables -k", 6) unless options[:k].nil?
  leave.("ERROR: -i disables -y", 6) unless options[:y].nil?
end
unless options[:y].nil? # y -d-> j
  leave.("ERROR: -y disables -j", 6) unless options[:j].nil?
end
unless options[:y].nil? # y -d-> l
  leave.("ERROR: -y requires -l", 7) if options[:l].nil?
end
unless options[:k].nil? # k -r-> l,m
  leave.("ERROR: -k requires -l", 7) if options[:l].nil?
  leave.("ERROR: -k requires -m", 7) if options[:m].nil?
  leave.("ERROR: -k requires -y", 7) if options[:y].nil?
end
unless options[:m].nil?
  leave.("ERROR: -m requires -k", 7) if options[:k].nil?
end

# Check group requirements
leave.("ERROR: at least one of {-n,-p} must be specified", 8) if (options[:n].nil? && options[:p].nil?)
leave.("ERROR: only one of {-q,-u} can be specified", 8) if (options[:q] && options[:u])
leave.("ERROR: {-v,-w} are mutually exclusive, but one is required", 8) unless (options[:v].nil? ^ options[:w].nil?)

# Required arguments must be present
leave.("ERROR: -A, -B, and -C are required", 9) if [:A,:B,:C].any? { |k| ! options.key?(k) }

# Check enum has a reasonable input choice
leave.("ERROR: -E must be one of 'a', 'b', or 'c'", 11) unless (options[:E].nil? || ['a','b','c'].include?(options[:E]))
leave.("ERROR: -i must be in {1,9}", 11) unless (options[:i].nil? || [1,9].include?( Integer(options[:i]) ))

# Check numerical type constraints
N_arg, I_arg = options[:N].nil? ? nil : options[:N].to_f, options[:I].nil? ? nil : options[:I].to_i
leave.("ERROR: -N must be in (7.7, 9.9]", 12) unless (N_arg.nil? || (N_arg > 7.7 && N_arg <= 9.9))
leave.("ERROR: -I must be in [-7,9)", 12) unless (I_arg.nil? || (I_arg >= -7 && I_arg < 9))
leave.("ERROR: -I must be an int", 12) unless ( I_arg.nil? || ( Integer(options[:I].to_s) rescue false ) )
(options[:L] || []).each do |v|
  leave.("ERROR: -L must be in [7,13)", 12) unless (v.to_i >= 7 && v.to_i < 13)
  leave.("ERROR: -L must be an int", 12) unless ( Integer(v.to_s) rescue false )
end

# Min and max list entries
leave.("ERROR: -e must have 2<=|v|<= 3", 13) unless (options[:e].nil? || (options[:e].length <= 3 && options[:e].length >= 2))
leave.("ERROR: -L must have 3<=|v|<= 5", 13) unless (options[:L].nil? || (options[:L].length <= 5 && options[:L].length >= 3))

# Write output files
(newName = options[:r]) ? FileUtils.touch(newName) : FileUtils.touch(DefReqOutName)
FileUtils.touch( options[:o] ) unless options[:o].nil?

# Print information about the command-line input
puts( "\nInputs given:".blue ) if verbose
options.each do |key,value|
  puts "\tINFO: #{value==true ? "Flag #{key} was present" : "Parameter #{key} was given value #{value}"}".blue if verbose
end

# It survived!
puts "Task completed!".green if verbose
exit 0

