
# This class is used by the API testing framework to
# parse the "req" files, which are simple description
# of an API request. The files were originally designed
# to be parsed by a Perl script to build 'curl' commands,
# but are used here to match the request to a CbrainClient
# API class and method.
#
# The file usually contain a single line, like one of these:
#
#   POST /users?ATOK
#   GET /userfiles/1?NTOK
#   POST /userfiles/delete_files
#   GET /userfiles/2/content?NTOK
#
# These will be matched to the CbrainClient classes resp:
#
#   CbrainClient::UsersApi.users_post
#   CbrainClient::UserfilesApi.userfiles_id_get
#   CbrainClient::UserfilesApi.userfiles_delete_files_delete
#   CbrainClient::UserfilesApi.userfiles_id_content_get
#
# These method names are created by convention by the
# Swagger API client generator for Ruby.
#
# In the case of the last example, the object created in this
# class will have the following attributes:
#
#   klass   == CbrainClient::UserfilesApi
#   method  == :userfiles_id_content_get
#   reqid   == 2
#   toktype == 'NTOK'  # optional
#
class ParseReq #:nodoc:

  attr_reader :req_file_path

  # Extracted from "req" file:
  attr_reader :klass, :method, :reqid, :toktype

  # Extracted from "in" file:
  attr_reader :in_array

  # Extracted from "out" file:
  attr_reader :expected_code, :expected_out

  class TestConfigurationError < ::RuntimeError ; end

  # Parse and store the content of a test req,
  # which consists of on "req" file and possibly
  # a "in.rb" and "out" file, e.g. one from a test set
  # like these files:
  #
  #   path/test1/req
  #   path/test1/in.rb
  #   path/test1/out
  #   path/test2/req
  #   path/test2/in.rb
  #   path/test3/req
  #   path/test4/req
  #   path/test4/out
  #
  # The argument is only the path to the "req" file,
  # the others will be loaded if found.
  def initialize(testfile) #:nodoc:
    @req_file_path = testfile
    parse_req_file(@req_file_path)
    parse_in_file(@req_file_path.sub(/req$/,"in.rb"))
    parse_out_file(@req_file_path.sub(/req$/,"out"))
    self
  end

  # Parses test file "path/to/in.rb"
  def parse_in_file(infile) #:nodoc:
    content = File.read(infile) rescue nil
    return if content.blank?
    @in_array = Array(eval content)
  rescue => ex
    raise TestConfigurationError.new("Bad file '#{infile}: got exception: #{ex.class} #{ex.message}")
  end

  # Parses test file "path/to/out"
  def parse_out_file(outfile) #:nodoc:
    content = File.read(outfile) rescue nil
    return if content.blank?
    content = content.split # first line is special
    if content[0] =~ /^\s*(\d\d\d)/ # first line is special: "200"
      @expected_code = Regexp.last_match[1].to_i
    else
      raise TestConfigurationError.new("Bad first line in '#{outfile}. Expected HTTP code.")
    end
    @expected_out = content[1,content.size-1].join("\n") if content.size > 1
  end

  # Parses main test file "path/to/req"
  def parse_req_file(testfile) #:nodoc:
    req = File.read(testfile)
    # E.g.
    # POST /users?ATOK
    # GET /userfiles/1?NTOK
    # POST /userfiles/delete_files
    # GET /userfiles/2/content
    unless req.match( /
                      \A
                      (\S+)        # CAPT 1: verb "POST" "GET" etc
                      \s+          # space
                      \/           # slash
                      (\w+)        # CAPT 2: "controller"
                        (?:          # grouping, not capturing
                          (\/\d+)?      # CAPT 3: "slash number"
                          (\/[a-z]\w+)? # CAPT 4: "slash action"
                        )?           # end group
                      (\?[AND]TOK)? # CAPT 5: "?ATOK" or "?NTOK" or "?DTOK"
                      $
                      /x
                    )
      raise TestConfigurationError.new("Oh oh bad unparsable red line in '$testfile': #{req}")
    end

    verb, controller, @reqid, action, @toktype = Regexp.last_match[1,5]

    #puts "MATCH: #{verb} | #{controller} | #{reqid.inspect} | #{action.inspect} | #{an_token.inspect}"

    # Clean up our captures #3, #4 and #5
    @reqid.gsub!("/","")   if @reqid.present?
    action.gsub!("/","")   if action.present?
    @toktype.gsub!("?","") if @toktype.present?

    # Figure out the full class name
    controller_klass = controller.classify.pluralize # "tool_configs" => "ToolConfigs"
    @klass    = "CbrainClient::#{controller_klass}Api".constantize rescue nil
    raise TestConfigurationError.new("Cannot figure out API class for request in '#{testfile}'. Got '#{controller_klass}' which is not a constant of CbrainClient.") if ! @klass

    # Figure out the full method name
    @method  = controller
    @method += "_id"        if @reqid.present?
    @method += "_#{action}" if action.present?
    @method += "_#{verb.downcase}"
    @method = @method.to_sym
    #puts_green "=======> #{klass}.#{@method}"

    # Verify that the method exists for the class
    handler = klass.new
    unless handler.respond_to? @method
      raise "Error parsing testfile '#{testfile}: class #{klass} has not method '#{@method}'"
    end

    self
  end

  # Attempt to run a test on a CbrainClient API method.
  # The cbclient argument is a CbrainClient::ApiClient object
  # that contains the appropriate credentials for the test.
  def runtest(cbclient) #:nodoc:

    # Let's verify we have all the information from the in.rb file.
    # This is a nice bit of meta programming btw.
    inspect_method = @klass.new.method(@method) # E.g. inspect users_post() of CbrainClient::UsersApi.new
    method_params  = inspect_method.parameters  # E.g. [ [ :req, :paramname ], [ :opt, :options ] ]
    needed         = method_params.count { |x| x[0] == :req }
    supplied       = @in_array ? @in_array.size : 0
    supplied      += 1 if @reqid
    if needed != supplied
      raise TestConfigurationError.new("Error: not enough params for #{@klass}.new.#{@method}(): got #{supplied}, needed #{needed}")
    end

    # Invoke the method with the proper client.
    handler      = @klass.new(cbclient)
    extra_method = "#{@method}_with_http_info".to_sym # these enhanced methods return triplets
    argarray     = @in_array ? @in_array.dup : []
    argarray.unshift(@reqid) if @reqid.present?
    result, code, headers = handler.send(extra_method,*argarray) # the splat operator sends nothing if argarray is empty!

    # Let's verify everything now
    errors = []

    # HTTP CODE
    if (@expected_code || 200) != code
      errors << "HTTPCODE: #{code} <> #{@expected_code}"
    end

    # CONTENT TYPE
    got_ctype = headers['Content-Type']
    exp_ctype = 'application/json' # FIXME hardcoded for the moment, make it changeable in the future
    if got_ctype != exp_ctype
      errors << "C_TYPE: #{got_ctype}"
    end

    # CONTENT
    if @expected_out.present?
      if clean_content(@expected_out) != clean_content(result)
        errors << "CONTENT DIFFERS"
      end
    end

    return errors
  end

  private

  # Used for content comparisons
  def clean_content(string, options={}) #:nodoc:
    clean = string.gsub(/\s+/,"")
    # remove dates: "2018-10-19T22:12:42.000Z"
    clean = clean.gsub(/"\d\d\d\d-\d\d-\d\d[T\s]\d\d:\d\d:\d\d[\d\.Z]*"/, "null")
    # remove "id":nnn if a POST (create operation)
    clean = clean.gsub(/"id":\d+/,'"id":new') if (options[:method] || "").upcase == "POST"
  end

end

