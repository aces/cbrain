
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
  attr_reader :req_file_base

  # Extracted from "req" file:
  attr_reader :klass, :method, :reqid, :toktype

  # Extracted from "in" file:
  attr_reader :in_array

  # Extracted from "out" file:
  attr_reader :expected_code, :expected_ctype, :zap_regex, :expected_out

  # Produced by test
  attr_reader :got_code, :got_ctype, :got_content

  # Config
  attr_writer :verbose

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
  def initialize(testfile,verbose = 1) #:nodoc:
    @req_file_path = testfile
    @req_file_base = testfile.sub(/req$/,"")
    @verbose = verbose
    parse_req_file(@req_file_path)
    parse_in_file("#{req_file_base}in.rb")
    parse_out_file("#{req_file_base}out")
    self
  end

  # Parses test file "path/to/in.rb"
  def parse_in_file(infile) #:nodoc:
    content = File.read(infile) rescue nil
    return if content.blank?
    @in_array = Array(eval content)
  rescue => ex
    raise TestConfigurationError.new("Bad file '#{infile}': got exception: #{ex.class} #{ex.message}")
  end

  # Parses test file "path/to/out"
  def parse_out_file(outfile) #:nodoc:
    content = File.read(outfile) rescue nil
    return if content.blank?
    content    = content.split(/\n/)
    first_line = content.shift.strip
    elems      = first_line.split(/\s+/) # "200 application/json regex regex regex"
    @expected_code  = elems[0].to_i
    @expected_ctype = elems[1] if elems.size > 1
    @zap_regex      = elems[2..elems.size-1] if elems.size > 2
    @expected_out   = content.join("\n")     if content.size > 0
  end

  # Parses main test file "path/to/req"
  def parse_req_file(testfile) #:nodoc:
    req = File.read(testfile)
    # E.g.
    # POST /users?ATOK
    # GET /userfiles/1?NTOK
    # POST /userfiles/delete_files
    # GET /userfiles/2/content
    # POST /userfiles/create?NTOK multipart/form-data
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
                      \s*
                      (\S*)         # CAPT 6: optional Content-type, not used here
                      $
                      /x
                    )
      raise TestConfigurationError.new("Oh oh bad unparsable req line in '$testfile'.")
    end

    verb, controller, @reqid, action, @toktype, _ctype  = Regexp.last_match[1,6]

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
    puts_green " => #{klass}.#{@method}" if @verbose > 1

    # Verify that the method exists for the class
    handler = klass.new
    unless handler.respond_to? @method
      raise "Parsing testfile '#{testfile}': class #{klass} has no such method '#{@method}'"
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
      raise TestConfigurationError.new("Not enough params for #{@klass}.new.#{@method}(): got #{supplied}, needed #{needed}")
    end

    # Invoke the method with the proper client.
    handler      = @klass.new(cbclient)
    extra_method = "#{@method}_with_http_info".to_sym # these enhanced methods return triplets
    argarray     = @in_array ? @in_array.dup : []
    argarray.unshift(@reqid) if @reqid.present?
    begin
      # Yeah, the splat operator doesn't add arguments if argarray is empty!
      result, @got_code, headers = handler.send(extra_method,*argarray)
    rescue CbrainClient::ApiError => ex
      result, @got_code, headers = ex.response_body, ex.code, ex.response_headers
    end

    # Let's verify everything now
    errors = []

    # HTTP CODE
    if (@expected_code || 200) != @got_code
      errors << "HTTPCODE: #{@got_code} <> #{@expected_code}"
    end

    # CONTENT TYPE
    @got_ctype = headers['Content-Type'] || "unk" # 'application/json ; charset=utf8'
    @got_ctype.sub!(/\s*;.*/,"")
    if @got_ctype != (@expected_ctype || 'application/json')
      errors << "C_TYPE: #{@got_ctype}"
    end

    # CONTENT
    if @expected_out.present?
      @expected_out = clean_content(@expected_out)
      @got_content  = clean_content(result)
      if @expected_out != @got_content
        errors << "CONTENT DIFFERS"
        if @verbose > 1
          puts_red "Got: #{@got_content}"
          puts_red "Exp: #{@expected_out}"
        end
      end
    end

    return errors
  end

  private

  # Used for content comparisons
  def clean_content(content) #:nodoc:
    return "" if content.blank?
    #content = content.map { |x| x.respond_to?(:to_json) x.to_json : x } if content.is_a?(Enumerable)
    string  = if content.is_a?(String)
                 content
              elsif content.respond_to?(:to_json)
                 content.to_json
              else
                 content.to_s
              end
    clean = string.gsub(/\s+/,"")
    # remove dates: "2018-10-19T22:12:42.000Z"
    clean = clean.gsub(/"\d\d\d\d-\d\d-\d\d[T\s]\d\d:\d\d:\d\d[\d\.Z]*"/, "null")
    # remove "id":nnn if a POST (create operation)
    clean = clean.gsub(/"id":\d+/,'"id":new') if @method =~ /_post$/
    # fix some inconsistencies in serializing json for true/false
    clean = clean.gsub(/:(true|false)/,':"\1"')
    # finaly, our customizable zappable substrings
    (@zap_regex || []).each do |sregex|
      #puts_yellow "==== Cleaning #{sregex}"
      regex = Regexp.new(sregex)
      #puts_yellow "Before: #{clean}"
      clean.gsub!(regex,"")
      #puts_yellow "After : #{clean}"
    end
    clean
  end

  # Utility that can be used inside a "in.rb" file. It
  # will read the "in.json" file that is at the exact same level
  # and return it all parsed. If arguments are given,
  # the top properties named by them will be fetched and
  # their values returned, in order, as elements of an array.
  #
  # Ex: given a in.json file with
  #
  #   {"user":{"login":"root"},"hello":"true"}
  #
  # Then the ruby code in in.rb could refer to
  # it with:
  #
  #   read_local_json "user", "hello"
  #
  # and this would produce the array:
  #
  #   [ { "login" => "root" }, "true" ]
  def read_local_json(*args)
    @_jscontent ||= File.read("#{@req_file_base}in.json")
    @_jsparsed  ||= JSON.parse(@_jscontent)
    return @_jsparsed.dup if args.size == 0
    @_jsparsed.slice(*args).values
  end

  # Utility that can be used in a "in.rb" file.
  # It creates a new instance of +klass+
  # and pass it, as an initialization argument,
  # a value fetched from the sibling jason file;
  # the value will be what's associated with the
  # top-level +property+ in the json.
  #
  # Ex: given a in.json file with
  #
  #   {"user":{"login":"root"}}
  #
  # Then the ruby code in in.rb could refer to
  # it with:
  #
  #   from_json("user",CbrainClient::CbUser)
  #
  # and this will have the effect of executing
  #
  #   CbrainClient::CbUser.new( :login => 'root' )
  def new_from_json(property,swagger_klass)
    swagger_klass.new(read_local_json[property])
  end

end

