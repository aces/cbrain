
# This module provides helper methods and constants to avoid cluttering the 
# actual Rspec test files too much. It is shared by the Boutiques tests
# on both the Bourreau and the Portal side. Note that it is specific to the 
# mocked Boutques test application boutiquesTestApp.rb.
module TestHelpers

  # External helper constants 
  TestScriptName           = 'boutiquesTestApp.rb'
  TestScriptDescriptor     = 'descriptor_test.json'
  ValidationScriptLocation = 'validator.rb'
  BoutiquesSchemaLocation  = '../../lib/cbrain_task_generators/schemas/boutiques.schema.json'

  ### Helper script argument-specific constants ###
  # Local name variables for outfile arguments
  DefReqOutName = 'r.txt' # Default name for required output
  AltReqOutName = 'r.csv' # Alternate name for required output
  OptOutName    = 'o.txt' # Optional output file name
  PotenOutFiles = [AltReqOutName, OptOutName, DefReqOutName]
  # Argument helper variables
  r_arg, o_arg = "-r #{AltReqOutName} ", "-o #{OptOutName} "
  reqArgs      = "-A a -B 9 -C c "            # Required args with values
  baseArgs     = "-A a -B 9 -C c -v s -n 7 "  # Basic minimal argument set
  baseArgs2    = "-p 7 s1 s2 -A a -B 9 -C c " # Alternate basic minimal arg set
  # Whether to print verbosely or not (helpful for debugging tests)
  Verbose = false

  # Execute program with given options
  def runTestScript(cmdOptions, outfileNamesToCheckFor = [])
    system( File.join(__dir__, TestScriptName + (Verbose ? ' --verbose ' : ' ') + cmdOptions) )
    outfileNamesToCheckFor.each { |n| return 11 unless File.exist?(n) }
    return $?.exitstatus
  end

  # JSON validation
  def runAndCheckJsonValidator
    validator  = File.join(__dir__, ValidationScriptLocation)
    schema     = File.join(__dir__, BoutiquesSchemaLocation)
    descriptor = File.join(__dir__, TestScriptDescriptor) 
    stdout     = `ruby #{validator} #{schema} #{descriptor}`
    return stdout.start_with?( '["OK"]' )
  end

  # Destroy output files of the mock program
  def destroyOutputFiles
    # Send the deletion request per output file that exists
    PotenOutFiles.each { |f| File.delete(f) if File.exist?(f) }
    # Ensure file is destroyed, so flow-through files do not confound following tests
    PotenOutFiles.each { |f| sleep(0.05) while File.exist?(f) }
  end

  ### RSpec Tests ###
  # We test the JSON descriptor 
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
  ###

  # Test program symbols
  TestArgs = [*'a'..'g',*'i'..'r',*'u'..'y',*'A'..'C'].map{ |s| s.to_sym } 

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
    ["works with optional file list", baseArgs2 + "-f f1 f2 -w", 0],
    ["works with optional file", baseArgs2 + "-d f  -w", 0],
    ["works with optional number list", baseArgs2 + "-g 1 2 3 -w", 0],
    # Disables & Requires
    ["works with inactive disabler", baseArgs + "-j jf", 0],
    ["works with disabler alone" , baseArgs + "-i 1", 0],
    ["works with requirement alone", baseArgs + "-l 9 7", 0],
    ["works with requirer's (y) requirements met + disabler alone", baseArgs + "-l 9 9 -y", 0],
    ["works with requirers' (m & k) requirements met", baseArgs + "-l 9 9 -k s -m t1 t2 -y", 0],
    # Group characteristics testing
    ["works with both members in one-is-required group (1)", baseArgs + "-j jf", 0],
    ["works with one member in mutex group (group 2 - with q)", baseArgs + "-q s", 0],
    ["works with one member in mutex group (group 2 - with u)", baseArgs + "-u", 0],
    # Output files testing
    ["has existent default output file", baseArgs, 0, [DefReqOutName] ],
    ["has mutable required output file name", baseArgs + r_arg, 0, [AltReqOutName] ],
    ["should not find the default required file when renamed", baseArgs + r_arg, 11, [DefReqOutName] ],
    ["outputs optional file", baseArgs + o_arg, 0, [DefReqOutName, OptOutName] ],
    ### Tests that should result in the program failing ###
    # Argument requirement failures
    ["fails when a required argument is missing (A: flag + value)", "-n 7 -B 7 -C c -v s", 9],
    ["fails when a required argument is missing (A: value)", "-n 7 -B 7 -C c -v s -A", 1],
    # Argument type failures
    ["fails when number (-B) is non-numeric (required)", "-n 7 -A a -B q -C c -v s -b 7", 1],
    ["fails when number (-b) is non-numeric (optional)", baseArgs + "-b u", 1],
    ["fails when number in list (-l) is non-numeric (optional)", baseArgs + "-l 2 u 2", 4],
    # Special separator failures
    ["fails when special separator is missing", baseArgs + "-x 7", 5],
    ["fails when special separator is wrong", baseArgs + "-x~7", 5],
    # Disables/requires failures
    ["fails if both disabler and target present (k)", baseArgs + "-i 9 -k s", 6],
    ["fails if both disabler and target present (k+s)", baseArgs + "-i 9 -j jf -k s", 6],
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
    ["fails with non-existent input file for list (-f)", baseArgs + "-f f1 f3 f2", 10],
    # Output file failures
    ["fails if the optional output file is specified but unnamed", baseArgs + "-o", 1]
  ]

  # Helper method for internally generating an argument dictionary similar to the "parameters" hash from a string
  # This is used to test the after_form method of the portal_task, in isolation
  # Occurences with lists after the flag become arrays. Lone flags become booleans indicating their presence.
  # e.g. {'a' => val_a, '-l' => [1,2], ...} when "-a val_a -l 1 2" appears in the string
  # Note: may wish to replace with a more general parser; this one is brittle and specific
  ArgumentDictionary = lambda do |args|
    # Helper function for finding the end of an argument
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

end

