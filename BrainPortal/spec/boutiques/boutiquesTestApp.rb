#!/usr/bin/env ruby

# This is the mock application used to test the Boutiques framework in cbrain.
# It tries to cover as many Boutiques features as possible.
# In essence, it takes a command line string as input and merely checks that the
# implied input parameters match the specifications (as in the json descriptor).
# The exit code of the script is used to test correctness in the unit tests of Boutiques.

require 'optparse'
require 'fileutils'

require_relative 'test_helpers' # To ensure files are written to the write temp place
include TestHelpers

# Colours
class String
  def colour(code) "\e[#{code}m#{self}\e[0m" end
  def red() colour(31) end
  def green() colour(32) end
  def blue() colour(34) end
end

# Print raw input string
print("\nRunning Boutiqes simple test app\nRaw Input=#{ARGV.to_s}".blue) if ARGV.include? "--verbose"

# Dictionary of inputs to be filled
options = {}

# Lists of potential input symbols
symbolize = lambda { |a| a.map{ |s| s.to_sym } }
Strings     = symbolize.( %w(a k q A v o x r) )
Flags       = symbolize.( %w(c u w y) )
Files       = symbolize.( %w(C d j) )
Numbers     = symbolize.( %w(B b n i) )
NumLists    = symbolize.( %w(g l) )
FileLists   = symbolize.( %w(f) )
StringLists = symbolize.( %w(p e m) )
Lists = NumLists + FileLists + StringLists

# Default required output name (override with -r)
DefaultRequiredOutputName = DefReqOutName # From helper module

# Verbose printing (set by command argument)
verbose = false

# Helper for exiting and printing error message (puts does not print arrays well)
leave = lambda { |msg,code| print ( "\n" + msg.to_s + "\n").red if verbose; exit code }

# The Ruby argument parser cannot nicely handle space-separated lists, so it is done now
toDel, listPos = [], []
listArgs = Lists.map{ |s| '-'+s.to_s} + Lists.map{ |s| "--arg_" + s.to_s }      # Potential list-type args
ARGV.each_with_index { |arg,ind| listPos << ind if listArgs.include?(arg) }     # Get list positions
nextEnd = lambda { |a,i| (i+=1) until i==a.length || a[i].start_with?('-'); i } # Helper to obtain list end
listPos.each do |i|
  toDel << i    # Store the parameter location for deletion
  strArray = [] # Holds the list elements
  ( (i+1)...nextEnd.(ARGV,i+1) ).each{ |j| strArray << ARGV[j]; toDel << j } # Grabs the list elements
  options[ ARGV[i].gsub(/^-*/,"").to_sym ] = strArray # Store them
end
toDel.sort.reverse.each { |i| ARGV.delete_at(i) } # Delete list arguments

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
op = OptionParser.new do |opt|
  opt.banner = "\nSimple Test Application for Boutiques in CBrain\n"

  # Basic required inputs
  opt.on('-A','--arg_r1 S',         'A required string input',  String) { |o| options[:A] = o }
  opt.on('-B','--arg_r2 N',         'A required number input',  Float ) { |o| options[:B] = o }
  opt.on('-C','--arg_r3 F',         'A required file input',    String) { |o| options[:C] = o }

  # Basic optional inputs
  opt.on('-a','--arg_a a_string',   'A string input',           String) { |o| options[:a] = o }
  opt.on('-b','--arg_b a_number',   'A numerical input',        Float ) { |o| options[:b] = o }
  opt.on('-c','--arg_c',            'A flag input'                    ) { |o| options[:c] = o }
  opt.on('-d','--arg_d a_filename', 'A file input',             String) { |o| options[:d] = o }
  opt.on('-e','--arg_e S1 S2',      'A string list input',      Array ) { |o| options[:e] = o }
  opt.on('-f','--arg_f F1 F2',      'A file list input',        Array ) { |o| options[:f] = o }
  opt.on('-g','--arg_g G1 G2',      'A number list input',      Array ) { |o| options[:g] = o }

  # Disables/Requires
  opt.on('-i','--arg_i a_number',   'A number input',           Float ) { |o| options[:i] = o }
  opt.on('-j','--arg_j a_file',     'A file input',             String) { |o| options[:j] = o }
  opt.on('-k','--arg_k a_string',   'A string input',           String) { |o| options[:k] = o }
  opt.on('-l','--arg_l N1 N2',      'A number list input',      Array ) { |o| options[:l] = o }
  opt.on('-m','--arg_m S1 S2',      'A string list input',      Array ) { |o| options[:m] = o }
  opt.on('-y','--arg_y',            'A flag input',                   ) { |o| options[:y] = o }

  # Groups (mutex/one-req)
  opt.on('-n','--arg_n n',          'A number input',           Float ) { |o| options[:n] = o }
  opt.on('-p','--arg_p S1 S2',      'A string list input',      Array ) { |o| options[:p] = o }
  opt.on('-q','--arg_q s',          'A string input',           String) { |o| options[:q] = o }
  opt.on('-u','--arg_u',            'A flag input',                   ) { |o| options[:u] = o }
  opt.on('-v','--arg_v a_str',      'A string input',           String) { |o| options[:v] = o }
  opt.on('-w','--arg_w',            'A flag input',                   ) { |o| options[:w] = o }

  # Non-space flag separator using '='
  opt.on('-x','--arg_x S',          'A string input',           String) { |o| options[:x] = o }

  # Optional and required output
  # Note: -r is a required output file, not a required input. It defaults writing out to r.txt.
  opt.on('-o','--arg_o fname',      'The output name string',   String) { |o| options[:o] = o }
  opt.on('-r','--arg_r fname',      'A required outfile name',  String) { |o| options[:r] = o }

  # Help display
  opt.on('-h','--help', "Displays help") { puts(opt.to_s + "\n"); exit }

  # Verbose mode
  opt.on('--verbose', "Prints more info during execution") { verbose = true }

end # End parser definition

# Perform the parsing
# Handle errors in the command line structure itself
# Errors here usually destroy the proper assignment of the other arguments, so such errors are fast-fail
begin
  op.parse!
rescue
  leave.( "ERROR: " + $!.to_s , 1)
end

# Ensure that all the arguments were parsed
if ARGV != []
  leave.("ERROR: leftover arguments " + ARGV.to_s, 1)
end

# Check input types
# The automatic parser already does this to an extent, but since it is incomplete and
# we also rely on some manual parsing, we check it again
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
    options[key] = value.map { |n| Float(n) rescue nil }
    msg = "ERROR: input list (-#{key.to_s}, #{value}) contained non-numeric elements"
    leave.(msg, 4) if options[key].include? nil
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

# Write output files
(newName = options[:r]) ? FileUtils.touch(newName) : FileUtils.touch(DefaultRequiredOutputName)
FileUtils.touch( options[:o] ) unless options[:o].nil?

# Print information about the command-line input
puts( "\nInputs given:".blue ) if verbose
options.each do |key,value|
  puts "\tINFO: #{value==true ? "Flag #{key} was present" : "Parameter #{key} was given value #{value}"}".blue if verbose
end

# It survived!
puts "Task completed!".green if verbose
exit 0

