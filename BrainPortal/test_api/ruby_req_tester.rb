
#
# This file shouldn't be run directly, but
# invoked through the rake task:
#
#   RAILS_ENV=test rake cbrain:api:client:test
#
# A prerequisite is to have run, first:
#
#   RAILS_ENV=test rake db:seed:test:api
#
# This file CAN be loaded into the Rails console, however,
# provided it was started in the test environment.

require File.expand_path('../lib/parse_req.rb', __FILE__)

# This class implements a test engine
# for loading, parsing, and executing CbrainClient
# API tests stored as a set of "req" files, which
# were originally designed to work with a curl-based
# testing framework.
class ClientReqTester #:nodoc:

  # These values must match what was seeded in the test DB
  # with RAILS_ENV=test rake cbrain:api:client:test
  NORM_TOKEN   = '0123456789abcdeffedcba9876543210'
  ADMIN_TOKEN  = '0123456789abcdef0123456789abcdef'
  DEL_TOKEN    = '0123456789abcdefffffffffffffffff'
  BAD_TOKEN    = "not_really_a_token_eh-#{Process.pid}"

  # First, the default config for an unlogged user.
  CbrainClient.configure do |config|
    # The key for 'normal user', as created in db:seed:test:api
    config.api_key['cbrain_api_token'] = BAD_TOKEN
    config.host                        = 'localhost:3000'
    config.scheme                      = 'http'
  end

  # Client for an unlogged user user
  @noclient    = CbrainClient::ApiClient.new # Use the defaults above

  # Client for a normal user
  @normclient  = CbrainClient::ApiClient.new
  normconfig   = @normclient.config = @normclient.config.dup # replace config with a clone
  normconfig.api_key = normconfig.api_key.merge({ 'cbrain_api_token' => NORM_TOKEN }) # replace hash

  # Client for a admin user
  @adminclient = CbrainClient::ApiClient.new
  adminconfig  = @adminclient.config = @adminclient.config.dup # replace config with a clone
  adminconfig.api_key = adminconfig.api_key.merge({ 'cbrain_api_token' => ADMIN_TOKEN }) # replace hash

  # Client for queries that delete its own token
  @delclient   = CbrainClient::ApiClient.new
  delconfig    = @delclient.config = @delclient.config.dup # replace config with a clone
  delconfig.api_key = delconfig.api_key.merge({ 'cbrain_api_token' => DEL_TOKEN }) # replace hash

  # This will help map the tokens keywords in the "req" files to the clients above
  @client_switcher=Hash.new(@noclient)
    .merge 'ATOK' => @adminclient, 'DTOK' => @delclient, 'NTOK' => @normclient

  attr_writer :reqfiles_root # Path to the root of the reqfiles directory tree
  attr_reader :reqfiles      # [ 'a/b/req', 'a/c/req' ... ]
  attr_reader :test_results  # { 'a/b/req' => [ 'error1', 'error2' ] }
  attr_accessor :verbose

  def self.client_switcher(reqtoken)
    @client_switcher[reqtoken]
  end

  def verify_config
    Rails.env == 'test' or
      raise "Oh oh, this program needs to be run in a 'test' environment!"
    @reqfiles_root.to_s.present? && File.directory?(@reqfiles_root.to_s) or
      raise "No proper root for the reqfiles"
  end

  def run_all_tests(filter = nil)
    @verbose ||= 1
    verify_config()
    load_all_reqfiles()
    filter_reqfiles(filter) if filter.present?
    reorder_reqfiles()
    @test_results ||= {}

    @reqfiles.each_with_index_and_size do |test,i,total|
      test_base   = Pathname.new(test).relative_path_from(Pathname.new(@reqfiles_root)).to_s
      test_base.sub!(/[\.\/]req$/,"") # make pretty
      pretty_name = sprintf("%3.3d/%3.3d : %s", i+1, total, test_base)
      result = run_one_test(test,pretty_name)
    end

    @test_results
  end

  def load_all_reqfiles
    @reqfiles = IO.popen("find #{@reqfiles_root.to_s.bash_escape} -name \"*req\" -print","r") { |fh| fh.readlines }
    @reqfiles.map! { |x| x.chomp } # just line in Perl, almost
    puts "\nFound #{@reqfiles.size} req files." if @verbose > 0
    if @verbose > 2
      @reqfiles.each { |file| puts " => #{file}" }
    end
  end

  def filter_reqfiles(substring)
    return if substring.blank?
    @reqfiles.select! { |x| x.index(substring) }
    puts "\nFiltered down to #{@reqfiles.size} req files." if @verbose > 1
    if @verbose > 2
      @reqfiles.each { |file| puts " => #{file}" }
    end
  end

  # Shuffling req files is special, in that
  # req files at the lowest level of a directory
  # tree must be tried in alphabetcal order,
  # but aside from that they should be able to be
  # run in arbitrary order compared to any other req
  # files elsewhere.
  def reorder_reqfiles
    by_prefixes = @reqfiles.hashed_partitions { |f| f.sub(/\/[^\/]+$/,"") }
    shuffled_prefixes = by_prefixes.keys.shuffle
    @reqfiles = shuffled_prefixes.inject([]) do |final,prefix|
      final += (by_prefixes[prefix].sort)
    end
    puts "\nShuffled req files." if @verbose > 1
    if @verbose > 2
      @reqfiles.each { |file| puts " => #{file}" }
    end
  end

  def failed_tests
    @test_results.select { |name,errors| errors.present? }
  end

  # Note: the arg list is fantastic, but it's Matsumoto's "least surprise"
  def run_one_test(testfile, pretty_name = testfile)
    @test_results ||= {}
    puts "Testing #{pretty_name}" if @verbose > 0
    parsed = ParseReq.new(testfile, @verbose)

    if @verbose > 2
      puts_green "REQ: Klass=#{parsed.klass} | Method=#{parsed.method} | ID=#{parsed.reqid} | Tok=#{parsed.toktype}"
      puts_green "IN : InArray=#{parsed.in_array.try(:size) || 'none'}"
      puts_green "ARG: #{parsed.in_array.inspect}" if @verbose > 3
      puts_green "OUT: Code=#{parsed.expected_code} | Ctype=#{parsed.expected_ctype} | Zap=#{parsed.zap_regex.try(:size) || 'none'} | Output=#{parsed.expected_out.try(:size) || 'none'}"
    end

    begin
      client = self.class.client_switcher(parsed.toktype)
      errors = parsed.runtest(client)
    rescue => ex
      errors = [ "Exception: #{ex.class} #{ex.message}" ]
      if @verbose > 3
        puts_red "Exception: #{ex.class} #{ex.message}"
        puts_red "Backtrace:\n" + ex.backtrace.join("\n") if @verbose > 4
      end
    end

    puts_yellow " => " + errors.join(", ") if errors.present? && @verbose > 1
    @test_results[pretty_name] = errors
  end

end


