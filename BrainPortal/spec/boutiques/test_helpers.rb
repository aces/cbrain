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

  # External helper constants
  TestScriptName           = 'boutiquesTestApp.rb'
  TestScriptDescriptor     = 'descriptor_test.json'
  ValidationScriptLocation = 'validator.rb'
  TempStore                = 'spec/fixtures/' # Site for temp file creation, as in other specs

  ### Helper script argument-specific constants ###
  # Local name variables for outfile arguments
  DefReqOutName = TempStore + 'r.txt' # Default name for required output
  AltReqOutName = TempStore + 'r.csv' # Alternate name for required output
  OptOutName    = TempStore + 'o.txt' # Optional output file name
  PotenOutFiles = [AltReqOutName, OptOutName, DefReqOutName]
  # Input file helper variables
  c_file, d_file, j_file  = TempStore + 'c', TempStore + 'f', TempStore + 'jf'
  f1_file, f2_file = TempStore + 'f1', TempStore + 'f2'
  f_files = f1_file + ' ' + f2_file
  # Argument helper variables
  r_arg, o_arg = "-r #{AltReqOutName} ", "-o #{OptOutName} "
  reqArgs      = "-A a -B 9 -C #{c_file} "            # Required args with values
  baseArgs     = "-A a -B 9 -C #{c_file} -v s -n 7 "  # Basic minimal argument set
  baseArgs2    = "-p 7 s1 s2 -A a -B 9 -C #{c_file} " # Alternate basic minimal arg set
  # Whether to print verbosely or not (helpful for debugging tests)
  Verbose = false

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
    FileUtils.touch(c_file)  # For -C
    FileUtils.touch(d_file)  # For -d
    FileUtils.touch(j_file)  # For -j
    [1,2].each { |i| FileUtils.touch(TempStore + "f#{i}") } # For -f
  end

  # Destroy Input files
  def destroyInputFiles
    ['c','f','jf','f1','f2'].map{|f| TempStore + f }.each { |f| File.delete(f) if File.exist?(f) }
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
  #     {B,b,n,i} are Numbers & {g,l} are Number Lists
  #     {c,u,w,y} are Flag type inputs
  #     {E} is an Enum type input
  ###

  # Test program symbols
  TestArgs = [*'a'..'g',*'i'..'r',*'u'..'y',*'A'..'C','E'].map{ |s| s.to_sym }

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
    ["works with optional file", baseArgs2 + "-d #{d_file} -w", 0],
    ["works with optional number list", baseArgs2 + "-g 1 2 3 -w", 0],
    # Disables & Requires
    ["works with inactive disabler", baseArgs + "-j #{j_file}", 0],
    ["works with disabler alone" , baseArgs + "-i 1", 0],
    ["works with requirement alone", baseArgs + "-l 9 7", 0],
    ["works with requirer's (y) requirements met + disabler alone", baseArgs + "-l 9 9 -y", 0],
    ["works with requirers' (m & k) requirements met", baseArgs + "-l 9 9 -k s -m t1 t2 -y", 0],
    # Group characteristics testing
    ["works with both members in one-is-required group (1)", baseArgs + "-j #{j_file}", 0],
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
    ["fails when a required argument is missing (A: flag + value)", "-n 7 -B 7 -C #{c_file} -v s", 9],
    ["fails when a required argument is missing (A: value)", "-n 7 -B 7 -C #{c_file} -v s -A", 1],
    # Argument type failures
    ["fails when number (-B) is non-numeric (required)", "-n 7 -A a -B q -C #{c_file} -v s -b 7", 1],
    ["fails when number (-b) is non-numeric (optional)", baseArgs + "-b u", 1],
    ["fails when number in list (-l) is non-numeric (optional)", baseArgs + "-l 2 u 2", 4],
    ["fails when enum is not given a reasonable value", baseArgs + '-E d', 11],
    # Special separator failures
    ["fails when special separator is missing", baseArgs + "-x 7", 5],
    ["fails when special separator is wrong", baseArgs + "-x~7", 5],
    # Disables/requires failures
    ["fails if both disabler and target present (k)", baseArgs + "-i 9 -k s", 6],
    ["fails if both disabler and target present (k+s)", baseArgs + "-i 9 -j #{j_file} -k s", 6],
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
    # Non-existent input arguments
    ["fails with non-existent input file (-C)", "-n 7 -A a -B 2 -C cc -v s -b 7", 10],
    ["fails with non-existent input file for list (-f)", baseArgs + "-f #{f1_file} f3 #{f2_file}", 10],
    # Output file failures
    ["fails if the optional output file is specified but unnamed", baseArgs + "-o", 1]
  ]

  # Helper method for internally generating an argument dictionary similar to the "parameters" hash from a string
  # This is used to unit test the after_form method of the portal_task, in isolation.
  # It is also used to simulate argument "parsing" when the portal arguments are sent for execution (see Bourreau-side tests).
  # Occurences with lists after the flag become arrays. Lone flags become booleans indicating their presence.
  # e.g. {:a => val_a, :l => [1,2], :v => true, ...} when "-a val_a -l 1 2 -v" appears in the string
  ArgumentDictionary = lambda do |args|
    # Helper function for finding the end of an argument (an issue to due the presence of lists)
    nextCmdFlagIndex = lambda { |a| i=1; (i+=1) until a[i].start_with?('-'); i }
    # Read through the argument string and turn it into a hash
    copy = args.dup; hash = {}
    while args != ""
      arr = args.split()
      i = nextCmdFlagIndex.(arr) rescue nil
      if i == 1 # Flag case
        hash[arr[0][1].to_sym] = true
        args = arr[1..-1].join(" ")
      elsif i == 2 # Single argument case
        hash[arr[0][1].to_sym] = arr[1]
        args = arr[2..-1].join(" ")
      elsif i == nil # Last argument case
        v = (arr.size==1) ? true : (arr.size==2 ? arr[1] : arr[1...arr.length])
        hash[arr[0][1].to_sym] = v
        args = ""
      else # List case
        hash[arr[0][1].to_sym] = arr[1...i]
        args = arr[i..-1].join(" ")
      end
    end
    # Fix issues with special separator argument -x
    # We put a boolean there if the wrong separator is used, so the after_form test fails properly
    xarg = copy.split.find { |a| a.start_with? "-x=" }
    hash.keys.each { |k| hash[k] = xarg[2..-1] if k==:x } unless xarg.nil?
    hash[:x] = false if hash.keys.include?(:x) and xarg.nil?
    # Return
    hash
  end

  # Helper for cleaning spaces after key subsitution, to make it easier to write the correct test result
  NormedTaskCmd = lambda do |task|
    task.cluster_commands[0].split.join(' ')
  end


end

