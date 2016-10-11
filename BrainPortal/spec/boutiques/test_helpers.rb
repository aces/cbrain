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

# This module provides helper methods and constants to avoid cluttering the
# actual Rspec test files too much. It is shared by the Boutiques tests
# on both the Bourreau and the Portal side. Note that it is specific to the
# mocked Boutiques test application boutiquesTestApp.rb.
module TestHelpers

  # Used to help in custom argument parsing
  require 'shellwords'
  require 'optparse'

  # External helper constants
  TestScriptName           = 'boutiquesTestApp.rb'
  TestScriptDescriptor     = 'descriptor_test.json'
  ValidationScriptLocation = 'validator.rb'
  TempStore                = File.join('spec','fixtures') # Site for temp file creation, as in other specs

  ### Helper script argument-specific constants ###
  # Local name variables for outfile arguments
  DefReqOutName = File.join(TempStore, 'r.txt') # Default name for required output
  AltReqOutName = File.join(TempStore, 'r.csv') # Alternate name for required output
  OptOutName    = File.join(TempStore, 'o.txt') # Optional output file name
  PotenOutFiles = [AltReqOutName, OptOutName, DefReqOutName]
  # Input file helper variables
  C_file, D_file, J_file  = File.join(TempStore, 'c'), File.join(TempStore, 'f'), File.join(TempStore, 'jf')
  F1_file, F2_file = File.join(TempStore, 'f1'), File.join(TempStore, 'f2')
  f_files = F1_file + ' ' + F2_file
  InputFilesList  = [C_file, D_file, J_file, F1_file, F2_file]
  InputFilesFlags = [  '-C',   '-d',   '-j',    '-f',    '-f']
  # Argument helper variables
  r_arg, o_arg = "-r #{AltReqOutName} ", "-o #{OptOutName} "
  reqArgs      = "-A a -B 9 -C #{C_file} "            # Required args with values
  baseArgs     = "-A a -B 9 -C #{C_file} -v s -n 7 "  # Basic minimal argument set
  baseArgs2    = "-p 7 s1 s2 -A a -B 9 -C #{C_file} " # Alternate basic minimal arg set
  # Whether to print verbosely or not (helpful for debugging tests)
  Verbose = false

  # Useful descriptive variables
  symbolize = lambda { |a| a.map{ |s| s.to_sym } }
  Strings     = symbolize.( %w(a k q A v o x r) )
  Enums       = symbolize.( %w(E) )
  Flags       = symbolize.( %w(c u w y) )
  Files       = symbolize.( %w(C d j) )
  Numbers     = symbolize.( %w(B b n i N I) )
  NumLists    = symbolize.( %w(g l L) )
  FileLists   = symbolize.( %w(f) )
  StringLists = symbolize.( %w(p e m) )
  Lists = NumLists + FileLists + StringLists

  # Execute program with given options
  def runTestScript(cmdOptions, outfileNamesToCheckFor = [])
    system( File.join(__dir__, TestScriptName + (Verbose ? ' --verbose ' : ' ') + cmdOptions) )
    outfileNamesToCheckFor.each { |n| return 11 unless File.exist?(n) }
    return $?.exitstatus
  end

  # JSON validation
  def runAndCheckJsonValidator(boutiquesSchemaLocation)
    validator  = File.join(__dir__, ValidationScriptLocation)
    schema     = boutiquesSchemaLocation.to_s
    descriptor = File.join(__dir__, TestScriptDescriptor)
    stdout     = `ruby #{validator} #{schema} #{descriptor}`
    return stdout.start_with?( '["OK"]' )
  end

  # Create mock input files
  define_method :createInputFiles do # Avoids new scope creation
    FileUtils.touch(C_file)  # For -C
    FileUtils.touch(D_file)  # For -d
    FileUtils.touch(J_file)  # For -j
    [1,2].each { |i| FileUtils.touch(File.join(TempStore, "f#{i}")) } # For -f
  end

  # Destroy Input files
  def destroyInputFiles
    ['c','f','jf','f1','f2'].map{|f| File.join(TempStore, f) }.each { |f| File.delete(f) if File.exist?(f) }
  end

  # Destroy output files of the mock program
  def destroyOutputFiles
    # Send the deletion request per output file that exists
    PotenOutFiles.each { |f| File.delete(f) if File.exist?(f) }
    # Ensure file is destroyed, so flow-through files do not confound following tests
    PotenOutFiles.each { |f| sleep(0.05) while File.exist?(f) }
  end

  ### RSpec Tests ###
  # We test the mock tool described by its JSON descriptor
  # Not all possible combinations of types for each situation are tested
  # Short tool description:
  #   Requirements
  #     -A, -B, -C are always required
  #     -a through -g are optional arguments of each type
  #     -h displays the tool help
  #     -i disables -j, -y, and -k
  #     -k requires -m, -y, and -l
  #     -m requires -k (mutual requirement)
  #     -y requires -l and disables -j (flags had strange bugs with disables/requires in cbrain)
  #     At least one of {-n, -p} is required
  #     At most one of {-q, -u} can be specified
  #     Exactly one of {-v, -w} must be given
  #     -x uses the special separator '=' rather than space
  #   Outputs (existence is validated)
  #     -r specifies a required output name (it is given a default name otherwise)
  #     -o specifies an optional output name (it is not written otherwise)
  #   Argument types
  #     {a,k,q,A,v,o,x} are String inputs & {p,e,m} are String Lists
  #     {C,d,j} are Files & {f} is a File List (arguments must exist)
  #     {B,b,n,i,N,I} are Numbers & {g,l,L} are Number Lists
  #     {c,u,w,y} are Flag type inputs
  #     {E} is an Enum type input
  ###

  # Test program symbols
  TestArgs = [*'a'..'g',*'i'..'r',*'u'..'y',*'A'..'C','E','N','I','L'].map{ |s| s.to_sym }

  # Basic tests used to test mock program functionality
  BasicTests = [
    ### Tests that should results in the program succeeding ###
    # Test with varied minimal inputs
    ["works with minimal inputs", baseArgs, 0],
    ["works with minimal inputs + change group 1 one-is-required", "-p s1 s2 " + reqArgs + " -v s", 0],
    ["works with minimal inputs + change group 3 one-is-required", "-n 7 " + reqArgs + " -w", 0],
    ["works with minimal inputs + change both group 1 & 3 one-is-required", baseArgs2 + "-w", 0],
    # Test special separator
    ["works with special separator", reqArgs + "-n 7 -w -x=xval", 0],
    # Optional inputs testing
    ["works with optional string", baseArgs2 + "-a s -w", 0],
    ["works with optional flag", baseArgs2 + "-c -w", 0],
    ["works with optional string list", baseArgs2 + "-e s1 s2 -w", 0],
    ["works with optional file list", baseArgs2 + "-f #{f_files} -w", 0],
    ["works with optional file", baseArgs2 + "-d #{D_file} -w", 0],
    ["works with optional number list", baseArgs2 + "-g 1 2 3 -w", 0],
    ["works with negative numbers in numerical list", baseArgs + "-g -1 -2.1 -3", 0],
    # Disables & Requires
    ["works with inactive disabler", baseArgs + "-j #{J_file}", 0],
    ["works with disabler alone" , baseArgs + "-i 1", 0],
    ["works with requirement alone", baseArgs + "-l 9 7", 0],
    ["works with requirer's (y) requirements met + disabler alone", baseArgs + "-l 9 9 -y", 0],
    ["works with requirers' (m & k) requirements met", baseArgs + "-l 9 9 -k s -m t1 t2 -y", 0],
    # Numeric constraints satisfied
    ["works with appropriately constrained float", baseArgs + "-N 7.9", 0],
    ["works with appropriately constrained float on boundary", baseArgs + "-N 9.9", 0],
    ["works with appropriately constrained int", baseArgs + "-I 0", 0],
    ["works with appropriately constrained int on boundary", baseArgs + "-I -7", 0],
    ["works with value in int list on numeric boundary", baseArgs + "-L 9 7 12", 0],
    # List constraints satisfied
    ["works with string list having the right number of entries", baseArgs + "-e s1 s2 s3", 0],
    ["works with number list having the right number of entries", baseArgs + "-L 11 8 9 10",  0],
    # Group characteristics testing
    ["works with both members in one-is-required group (1)", baseArgs + "-j #{J_file}", 0],
    ["works with one member in mutex group (group 2 - with q)", baseArgs + "-q s", 0],
    ["works with one member in mutex group (group 2 - with u)", baseArgs + "-u", 0],
    # Output files testing
    ["has existent default output file", baseArgs, 0, [DefReqOutName] ],
    ["has mutable required output file name", baseArgs + r_arg, 0, [AltReqOutName] ],
    ["should not find the default required file when renamed", baseArgs + r_arg, 11, [DefReqOutName] ],
    ["outputs optional file", baseArgs + o_arg, 0, [DefReqOutName, OptOutName] ],
    ["works with a correctly specified enum", baseArgs + '-E c', 0],
    ### Tests that should result in the program failing ###
    # Argument requirement failures
    ["fails when a required argument is missing (A: flag + value)", "-n 7 -B 7 -C #{C_file} -v s", 9],
    ["fails when a required argument is missing (A: value)", "-n 7 -B 7 -C #{C_file} -v s -A", 1],
    # Argument type failures
    ["fails when number (-B) is non-numeric (required)", "-n 7 -A a -B q -C #{C_file} -v s -b 7", 3],
    ["fails when number (-b) is non-numeric (optional)", baseArgs + "-b u", 3],
    ["fails when number in list (-l) is non-numeric (optional, pos 2)", baseArgs + "-l 2 u 2", 4],
    ["fails when number in list (-l) is non-numeric (optional, pos 1)", baseArgs + "-l u 1 2", 4],
    ["fails when enum is not given a reasonable value", baseArgs + '-E d', 11],
    # Special separator failures
    ["fails when special separator is missing", baseArgs + "-x 7", 5],
    ["fails when special separator is wrong", baseArgs + "-x~7", 5],
    # Number constraints on lists
    ["fails when int list contains non-int", baseArgs + "-L 9 9.1 12", 12],
    ["fails when list entry is too low", baseArgs + "-L 9 6 12", 12],
    ["fails when list entry is too high", baseArgs + "-L 9 15 12", 12],
    ["fails when list entry is on excluded boundary", baseArgs + "-L 9 13 12", 12],
    # List constraint failures
    ["fails when string list entries are too few", baseArgs + "-e hi", 13],
    ["fails when string list entries are too many", baseArgs + "-e a b c d", 13],
    ["fails when number list entries are too few", baseArgs + "-L 11 12", 13],
    ["fails when number list entries are too many", baseArgs + "-L 7 8 9 10 11 12", 13],
    # Numeric constraints failures
    ["fails when float is under min", baseArgs + "-N 7", 12],
    ["fails when float is over max", baseArgs + "-N 13", 12],
    ["fails when float is on prohibited boundary", baseArgs + "-N 7.7", 12],
    ["fails when int is not an int", baseArgs + "-I 7.9", 12],
    ["fails when int is under min", baseArgs + "-I -9", 12],
    ["fails when int is over max", baseArgs + "-I 13", 12],
    ["fails when int is on prohibited boundary", baseArgs + "-I 9", 12],
    # Disables/requires failures
    ["fails if both disabler and target present (k)", baseArgs + "-i 9 -k s", 6],
    ["fails if both disabler and target present (k+s)", baseArgs + "-i 9 -j #{J_file} -k s", 6],
    ["fails if both disabler and target present (flag: y)", baseArgs + "-i 9 -y", 6],
    ["fails when requirement missing (k: no m [number])", baseArgs + "-k s -l 1 2", 7],
    ["fails when requirement missing (k: no l [string])", baseArgs + "-k s -m s1 s2", 7],
    ["fails when requirement missing (k: no y [flag])", baseArgs + "-k s -m s1 s2 -l 1 2", 7],
    ["fails when requirement missing (flag case: y - no l)", baseArgs + "-y", 7],
    # Group tests
    ["fails if group one-is-required is violated (group 1)", reqArgs + "-w", 8],
    ["fails if group mutex is violated (group 2)", baseArgs + "-q s -u", 8],
    ["fails if group one-is-required is violated (group 3)", reqArgs + "-n 7", 8],
    ["fails if group mutex is violated (group 3)", reqArgs + "-n 7 -v s -w", 8],
    # Superfluous argument failures
    ["fails with unrecognized flagged arguments", baseArgs + "-z", 1],
    ["fails with unrecognized non-flagged arguments", baseArgs + "z", 1],
    # Output file failures
    ["fails if the optional output file is specified but unnamed", baseArgs + "-o", 1]
  ]

  # Minimal arguments that could be used to run the task
  MinArgs = baseArgs.dup

  # Creates the option parser object used by the mock app to parse the input command line
  GenerateOptionParser = lambda do |options|
    return OptionParser.new do |opt|
      opt.banner = "\nSimple Test Application for Boutiques in CBrain\n"
      # Basic required inputs
      opt.on('-A','--arg_r1 S',         'A required string input',  String) { |o| options[:A] = o }
      opt.on('-B','--arg_r2 N',         'A required number input',  String) { |o| options[:B] = o }
      opt.on('-C','--arg_r3 F',         'A required file input',    String) { |o| options[:C] = o }
      # Basic optional inputs
      opt.on('-a','--arg_a a_string',   'A string input',           String) { |o| options[:a] = o }
      opt.on('-b','--arg_b a_number',   'A numerical input',        String) { |o| options[:b] = o }
      opt.on('-c','--arg_c',            'A flag input'                    ) { |o| options[:c] = o }
      opt.on('-d','--arg_d a_filename', 'A file input',             String) { |o| options[:d] = o }
      opt.on('-e','--arg_e S1 S2',      'A string list input',      Array ) { |o| options[:e] = o }
      opt.on('-f','--arg_f F1 F2',      'A file list input',        Array ) { |o| options[:f] = o }
      opt.on('-g','--arg_g G1 G2',      'A number list input',      Array ) { |o| options[:g] = o }
      opt.on('-E','--arg_E val',        'An enum input in {a,b,c}', String) { |o| options[:E] = o }
      opt.on('-N','--arg_N num',        'A number in (7.7, 9.9]',   String) { |o| options[:N] = o }
      opt.on('-I','--arg_I num',        'An integer in [-7,9)',     String) { |o| options[:I] = o }
      opt.on('-L','--arg_L x y',        'An int list in [7,13)',    Array ) { |o| options[:L] = o }
      # Disables/Requires
      opt.on('-i','--arg_i a_number',   'A number input',           String) { |o| options[:i] = o }
      opt.on('-j','--arg_j a_file',     'A file input',             String) { |o| options[:j] = o }
      opt.on('-k','--arg_k a_string',   'A string input',           String) { |o| options[:k] = o }
      opt.on('-l','--arg_l N1 N2',      'A number list input',      Array ) { |o| options[:l] = o }
      opt.on('-m','--arg_m S1 S2',      'A string list input',      Array ) { |o| options[:m] = o }
      opt.on('-y','--arg_y',            'A flag input',                   ) { |o| options[:y] = o }
      # Groups (mutex/one-req)
      opt.on('-n','--arg_n n',          'A number input',           String) { |o| options[:n] = o }
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
      opt.on('--verbose', "Prints more info during execution") { options[:verbose] = true }
    end # Parser definition
  end

  # The Ruby Option Parser cannot nicely handle space-separated lists, so it is done manually
  # We detect lists in args, add them to options, and then delete them from args
  HandleSpaceSeparatedLists = lambda do |args,options|
    toDel, listPos = [], []
    listArgs = Lists.map{ |s| '-' + s.to_s} + Lists.map{ |s| "--arg_" + s.to_s }  # Potential list-type args
    args.each_with_index { |arg,ind| listPos << ind if listArgs.include?(arg) } # Get list positions
    nextEnd = lambda do |a,i| # Helper to obtain list end
      (i+=1) until i==a.length || (a[i].start_with?('-') && TestArgs.map{ |s| '-' + s.to_s }.include?(a[i])); i
    end
    listPos.each do |i|
      toDel << i    # Store the parameter location for deletion
      strArray = [] # Holds the list elements
      ( (i+1)...nextEnd.(args,i+1) ).each{ |j| strArray << args[j]; toDel << j } # Grabs the list elements
      options[args[i].gsub(/^-*/,"").to_sym ] = strArray # Store them
    end
    toDel.sort.reverse.each { |i| args.delete_at(i) } # Delete list arguments
  end

  # Helper method for internally generating an argument dictionary similar to the "parameters" hash from a string
  # This is used to unit test the after_form method of the portal_task, in isolation.
  # It is also used to simulate argument "parsing" when the portal arguments are sent for execution (see Bourreau-side tests).
  # Occurences with lists after the flag become arrays. Lone flags become booleans indicating their presence.
  # e.g. {:a => val_a, :l => [1,2], :v => true, ...} when "-a val_a -l 1 2 -v" appears in the string
  ArgumentDictionary = lambda do |argsIn, idsForFiles=nil|
    # This will hold the output hash arguments
    hash, copy = {}, argsIn.dup
    # Shellify the input string
    args = Shellwords.shellwords(argsIn)
    # Must handle space-separated lists separately
    HandleSpaceSeparatedLists.( args, hash )
    # This will generate a parser and run it on the input args
    GenerateOptionParser.( hash ).parse( args )
    # Fix issues with special separator argument -x
    # We put a boolean there if the wrong separator is used, so the after_form test fails properly
    xarg = copy.split.find { |a| a.start_with? "-x=" }
    hash.keys.each { |k| hash[k] = xarg[2..-1] if k==:x } unless xarg.nil?
    hash[:x] = false if hash.keys.include?(:x) and xarg.nil?
    # Replace file paths with ids
    unless idsForFiles.nil?
      hash.each do |k,v|
        if FileLists.include? k
          hash[k] = v.map { |filepath| idsForFiles[ InputFilesList.find_index(filepath) ] }
        else
          hash[k] = idsForFiles[ InputFilesList.find_index(v) ] if InputFilesList.include? v
        end
      end
    end
    # Return
    hash
  end

  # Transform a cbrain command line, from apply_template, to a locally compatible one.
  # This is needed because our test app runs locally, rather than through cbrain, for many tests,
  # as well as the need (or recommendation at least) to keep the temporary files outside of '.',
  # unlike what is done in cbrain.
  # TODO The need for this should be examined; e.g. by executing through cbrain or
  # putting the temporary files in '.', we can avoid it
  FileNamesToPaths = lambda do |cmdLine|
    basenames = InputFilesList.map { |q| File.basename( q ) }
    basenames.zip( InputFilesFlags , InputFilesList).each_with_index do |(base,flag,fpath),i|
      if i == 4 then next  # Handled below in i == 3
      elsif i == 3 # Special case for the file list
        cmdLine.gsub!(/#{flag} #{basenames[i]} #{basenames[i+1]}/, "#{flag} #{InputFilesList[i]} #{InputFilesList[i+1]}")
      end
      cmdLine.gsub!(/#{flag} #{base}/, "#{flag} #{fpath}" )
    end
    cmdLine
  end

  # Helper for cleaning spaces after key subsitution, to make it easier to write the correct test result
  # Ignores the export commands and assumes the final command is the log writer
  NormedTaskCmd = lambda do |task|
    task.cluster_commands[-2].split.join(' ')
  end

  # A mock json task object, to test possible problems that the full mock app cannot be used to reproduce
  # e.g. a bug incurred when group constraints were present without any disables-inputs/requires-inputs being so
  # Note the method generates a new task each time
  NewMinimalTask = -> {
    {
      'name'           => "MinimalTest",
      'tool-version'   => "9.7.13",
      'description'    => "Minimal test task for Boutiques",
      'command-line'   => '/minimalApp [A]',
      'schema-version' => '0.2',
      'inputs'         => [GenerateJsonInputDefault.('a','String','A String arg')],
      'output-files'   => [{'id' => 'u', 'name' => 'U', 'path-template' => '[A]'}],
    }
  }

  # Helper to generate simple json inputs with default values
  GenerateJsonInputDefault = lambda do |id,type,desc,otherParams = {}|
    return {
      'id'                => id,
      'name'              => id.upcase,
      'type'              => type,
      'description'       => desc,
      'command-line-flag' => "-#{id}",
      'command-line-key'  => "[#{id.upcase}]",
      'optional'          => true
    }.merge( otherParams )
  end

end

